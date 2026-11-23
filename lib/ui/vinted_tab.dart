import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/models.dart';
import '../core/valuator.dart';
import '../core/vinted_page.dart';
import '../services/scout.dart';
import 'theme.dart';

/// Vinted dentro l'app: l'utente naviga, l'app mette un bollino di
/// valutazione su ogni annuncio visibile. Niente ricerche in sottofondo.
class VintedTab extends StatefulWidget {
  final Scout scout;
  final bool active;
  const VintedTab({super.key, required this.scout, required this.active});

  @override
  State<VintedTab> createState() => _VintedTabState();
}

class _VintedTabState extends State<VintedTab> {
  late final WebViewController _web;
  Timer? _timer;
  String _query = '';
  String _url = '';
  bool _loading = true;
  int _deals = 0;

  /// Bollini già calcolati: id Vinted -> (testo, colore css).
  final Map<String, (String, String)> _badges = {};
  final Set<String> _ingested = {};

  @override
  void initState() {
    super.initState();
    final qs = widget.scout.store.queries;
    _query = qs.isEmpty ? 'seiko' : qs.first;
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('Scout', onMessageReceived: _onItems)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => mounted ? setState(() => _loading = true) : null,
        onPageFinished: (u) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _url = u;
          });
          _collect();
        },
        onUrlChange: (c) {
          if (mounted && c.url != null) setState(() => _url = c.url!);
        },
      ))
      ..loadRequest(vintedSearchUri(_query));
    _syncTimer();
  }

  @override
  void didUpdateWidget(VintedTab old) {
    super.didUpdateWidget(old);
    _syncTimer();
  }

  /// Rilegge la pagina ogni pochi secondi solo mentre la scheda è aperta
  /// (Vinted carica altri annunci scorrendo).
  void _syncTimer() {
    if (widget.active && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _collect());
    } else if (!widget.active) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _collect() async {
    try {
      await _web.runJavaScript(vintedCollectorJs);
    } catch (_) {}
  }

  Future<void> _onItems(JavaScriptMessage m) async {
    List<Listing> listings;
    try {
      listings = parseVintedPage(m.message, watchCategory: vintedHasCategory(_url));
    } catch (_) {
      return;
    }
    final v = widget.scout.valuator;
    final fresh = <Listing>[];
    final marks = StringBuffer();
    for (final l in listings) {
      final key = l.id.substring('Vinted:'.length);
      final val = v.evaluate(l);
      final badge = _badgeFor(val);
      if (badge == null) {
        _badges.remove(key);
      } else {
        _badges[key] = badge;
      }
      if (_ingested.add(l.id)) fresh.add(l);
    }
    _badges.forEach((id, b) {
      final label = b.$1.replaceAll("'", "\\'");
      marks.write("window.__scoutMark && __scoutMark('$id','$label','${b.$2}');");
    });
    if (marks.isNotEmpty) {
      try {
        await _web.runJavaScript(marks.toString());
      } catch (_) {}
    }
    if (fresh.isNotEmpty) {
      await widget.scout.ingestAll(fresh, alert: false);
    }
    final deals = _badges.values.where((b) => b.$1.startsWith('Affare')).length;
    if (mounted && deals != _deals) setState(() => _deals = deals);
  }

  (String, String)? _badgeFor(Valuation v) {
    String hex(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final margin = v.margin == null ? '' : ' +${v.margin!.round()}€';
    return switch (v.verdict) {
      Verdict.affare => ('Affare ${v.score}$margin', hex(Brandbook.verde)),
      Verdict.interessante => ('Interessante ${v.score}', hex(Brandbook.arancio)),
      Verdict.daVerificare => ('Da verificare', hex(Brandbook.blu)),
      Verdict.normale => (
          'Vale ${euro(v.valueLow)}–${euro(v.valueHigh)}'.replaceAll(' €', ''),
          '#6b6b6b'
        ),
      Verdict.scartato => ('Scartato', hex(Brandbook.rosso)),
      Verdict.nonPertinente => null,
    };
  }

  void _search(String q) {
    setState(() => _query = q);
    _badges.clear();
    _web.loadRequest(vintedSearchUri(q));
  }

  @override
  Widget build(BuildContext context) {
    final queries = widget.scout.store.queries;
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            children: [
              IconButton(
                tooltip: 'Indietro',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  if (await _web.canGoBack()) await _web.goBack();
                },
                icon: const Icon(Icons.arrow_back),
              ),
              for (final q in queries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(q),
                    selected: q == _query,
                    onSelected: (_) => _search(q),
                  ),
                ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Brandbook.blu.withValues(alpha: 0.06),
          child: Text(
            vintedHasCategory(_url)
                ? (_deals == 0
                    ? 'Scorri: metto un bollino su ogni annuncio'
                    : '$_deals affari in questa pagina')
                : 'Consiglio: nei filtri di Vinted scegli Categoria → Orologi',
            style: TextStyle(
                fontSize: 12,
                color: _deals > 0 ? Brandbook.verde : Colors.grey.shade800,
                fontWeight: _deals > 0 ? FontWeight.w600 : FontWeight.w400),
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: WebViewWidget(controller: _web)),
      ],
    );
  }
}
