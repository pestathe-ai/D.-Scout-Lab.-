/// Lettura degli annunci visibili sulla pagina Vinted aperta dall'utente.
/// Solo logica pura: lo script JS raccoglie i dati grezzi, qui si interpretano.
library;

import 'dart:convert';

import 'models.dart';
import 'parsers.dart';
import 'text_utils.dart';

/// Script iniettato nella pagina: raccoglie i box degli annunci (link a
/// /items/...) con il loro testo e li manda all'app tramite il canale Scout.
/// Espone anche window.__scoutMark(id, testo, colore) per i bollini.
const vintedCollectorJs = r'''
(function () {
  if (!window.__scoutMark) {
    window.__scoutMark = function (id, label, color) {
      var a = document.querySelector('a[href*="/items/' + id + '"]');
      if (!a) return;
      var box = a.closest('[data-testid*="item"]') || a.parentElement;
      if (!box) return;
      var old = box.querySelector('.scout-badge');
      if (old) old.remove();
      if (getComputedStyle(box).position === 'static') box.style.position = 'relative';
      var b = document.createElement('div');
      b.className = 'scout-badge';
      b.textContent = label;
      b.style.cssText = 'position:absolute;top:6px;left:6px;z-index:9999;padding:3px 7px;' +
        'border-radius:999px;font:600 11px sans-serif;color:#fff;background:' + color +
        ';box-shadow:0 1px 3px rgba(0,0,0,.3);pointer-events:none;max-width:90%;';
      box.appendChild(b);
    };
  }
  var seen = {};
  var out = [];
  var links = document.querySelectorAll('a[href*="/items/"]');
  for (var i = 0; i < links.length; i++) {
    var a = links[i];
    var m = a.href.match(/\/items\/(\d+)/);
    if (!m || seen[m[1]]) continue;
    seen[m[1]] = true;
    var box = a.closest('[data-testid*="item"]') || a.parentElement;
    var text = (box && box.innerText) || '';
    var img = box && box.querySelector('img');
    out.push({
      id: m[1],
      url: a.href.split('?')[0],
      title: a.getAttribute('title') || (img && img.getAttribute('alt')) || '',
      text: text.slice(0, 400)
    });
  }
  if (out.length && window.Scout) Scout.postMessage(JSON.stringify(out));
})();
''';

/// Converte i dati raccolti dalla pagina in annunci.
/// Il titolo dei box Vinted di solito è "Titolo, marca: X, condizioni: Y, 45,00 €, ...".
List<Listing> parseVintedPage(String message,
    {bool watchCategory = false, DateTime? at}) {
  final data = jsonDecode(message);
  if (data is! List) return const [];
  final now = at ?? DateTime.now();
  final out = <Listing>[];
  for (final e in data) {
    if (e is! Map) continue;
    final id = str(e['id']);
    if (id == null) continue;
    final rawTitle = str(e['title']) ?? '';
    final text = str(e['text']) ?? '';
    final parts = rawTitle.split(',').map((s) => s.trim()).toList();
    String? brand;
    final kept = <String>[];
    for (final p in parts) {
      final l = p.toLowerCase();
      if (l.startsWith('marca:') || l.startsWith('brand:')) {
        brand = p.substring(p.indexOf(':') + 1).trim();
      } else {
        kept.add(p);
      }
    }
    final title = kept.isNotEmpty ? kept.first : text.split('\n').first;
    // Prezzo: il primo prezzo del titolo o del box (il secondo è con le commissioni).
    final price = parsePrice(rawTitle) ?? parsePrice(text);
    out.add(Listing(
      id: 'Vinted:$id',
      source: 'Vinted',
      title: title,
      text: [...kept.skip(1), if (rawTitle.isEmpty) text]
          .join(' · ')
          .replaceAll(RegExp(r'\s+'), ' '),
      price: price,
      seenAt: now,
      url: str(e['url']),
      isWatch: watchCategory ? true : null,
      siteBrand: brand,
    ));
  }
  return out;
}

/// Indirizzo di ricerca Vinted per una parola, dai più recenti.
Uri vintedSearchUri(String query) => Uri.https('www.vinted.it', '/catalog',
    {'search_text': query, 'order': 'newest_first'});

/// Vero se l'utente ha scelto una categoria nei filtri di Vinted.
bool vintedHasCategory(String url) =>
    url.contains('catalog%5B%5D=') ||
    url.contains('catalog[]=') ||
    RegExp(r'/catalog/\d+').hasMatch(url);

