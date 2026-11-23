// Mostra come Subito e Wallapop indicano la categoria degli annunci.
import 'dart:convert';
import 'dart:io';

import '../../lib/core/http_search.dart';
import '../../lib/core/parsers.dart';

String esc(String s) =>
    s.replaceAll('%', '%25').replaceAll('\r', '').replaceAll('\n', '%0A');

String short(Object? o, [int n = 900]) {
  final s = jsonEncode(o);
  return s.length > n ? s.substring(0, n) : s;
}

Future<String> get(HttpClient c, Uri u, [Map<String, String> h = const {}]) async {
  final rq = await c.getUrl(u);
  h.forEach(rq.headers.set);
  final r = await rq.close();
  return '${r.statusCode}\n${await r.transform(utf8.decoder).join()}';
}

Future<void> main() async {
  final c = HttpClient()..userAgent = userAgent;
  // Subito
  final sub = await get(c, Uri.https('www.subito.it', '/annunci-italia/vendita/usato/', {'q': 'omega', 'order': 'datedesc'}));
  final raw = extractNextData(sub.substring(sub.indexOf('\n') + 1));
  if (raw != null) {
    final data = jsonDecode(raw);
    final maps = findMaps(data, (m) => m['subject'] is String && m.containsKey('urn'));
    final cats = <String>{};
    for (final m in maps) {
      cats.add('${short(m['category'], 150)} :: ${m['subject']}');
    }
    print('::notice title=subito categories::${esc(cats.take(25).join('\n'))}');
    if (maps.isNotEmpty) {
      final m = maps.first;
      print('::notice title=subito item keys::${esc('${m.keys.toList()}\nfeatures: ${short(m['features'], 1500)}')}');
    }
    // filtri disponibili nella pagina
    final f = findMaps(data, (m) => m.containsKey('friendly_name') || m.containsKey('friendlyName'));
    print('::notice title=subito category list::${esc(f.take(60).map((m) => short(m, 160)).join('\n'))}');
  } else {
    print('::warning title=subito::no next data');
  }
  // Subito categoria abbigliamento-accessori
  final sub2 = await get(c, Uri.https('www.subito.it', '/annunci-italia/vendita/abbigliamento-accessori/', {'q': 'omega'}));
  print('::notice title=subito abbigliamento::${esc('status ${sub2.split('\n').first}')}');
  // Wallapop
  final w = await get(c, Uri.https('api.wallapop.com', '/api/v3/search', {
    'keywords': 'omega', 'source': 'search_box', 'order_by': 'newest',
    'latitude': '41.9028', 'longitude': '12.4964'}),
    {'X-DeviceOS': '0', 'Accept': 'application/json'});
  final wd = jsonDecode(w.substring(w.indexOf('\n') + 1));
  final items = findMaps(wd, (m) => m['title'] is String && m['web_slug'] is String);
  if (items.isNotEmpty) {
    print('::notice title=wallapop item keys::${esc('${items.first.keys.toList()}\n${short(items.first, 1200)}')}');
    print('::notice title=wallapop cats::${esc(items.take(25).map((m) => '${m['category_id']} ${short(m['taxonomy'], 120)} :: ${m['title']}').join('\n'))}');
  }
  c.close(force: true);
}
