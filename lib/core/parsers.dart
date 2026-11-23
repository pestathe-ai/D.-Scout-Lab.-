/// Lettura dei risultati di ricerca dei siti di annunci.
/// Solo logica pura (niente rete), così si può testare.
library;

import 'dart:convert';

import 'text_utils.dart';

class RemoteItem {
  final String source;
  final String id;
  final String title;
  final String description;
  final double? price;
  final String? url;
  final String? imageUrl;
  final String? place;

  /// Categoria del sito: true = orologi, false = altra categoria,
  /// null = il sito non lo dice.
  final bool? isWatch;

  /// Marca scelta dal venditore nel modulo del sito (se c'è).
  final String? siteBrand;

  const RemoteItem({
    required this.source,
    required this.id,
    required this.title,
    this.description = '',
    this.price,
    this.url,
    this.imageUrl,
    this.place,
    this.isWatch,
    this.siteBrand,
  });

  @override
  String toString() => '$source #$id "$title" ${price ?? '-'}€ ${url ?? ''}';
}

// ---------------- helper JSON ----------------

/// Visita ricorsivamente un JSON e restituisce le mappe per cui [test] è vero.
/// Non scende dentro una mappa che ha già dato esito positivo.
List<Map<String, dynamic>> findMaps(
    dynamic node, bool Function(Map<String, dynamic>) test) {
  final out = <Map<String, dynamic>>[];
  void walk(dynamic n, int depth) {
    if (depth > 40) return;
    if (n is Map) {
      final m = n.map((k, v) => MapEntry(k.toString(), v));
      if (test(m)) {
        out.add(m);
        return;
      }
      for (final v in m.values) {
        walk(v, depth + 1);
      }
    } else if (n is List) {
      for (final v in n) {
        walk(v, depth + 1);
      }
    }
  }

  walk(node, 0);
  return out;
}

dynamic dig(dynamic node, List<Object> path) {
  var cur = node;
  for (final p in path) {
    if (p is String && cur is Map) {
      cur = cur[p];
    } else if (p is int && cur is List && p < cur.length) {
      cur = cur[p];
    } else {
      return null;
    }
  }
  return cur;
}

String? str(dynamic v) {
  if (v == null) return null;
  if (v is String) return v.trim().isEmpty ? null : v.trim();
  if (v is num || v is bool) return v.toString();
  return null;
}

/// Prezzo da valori come 120, "120.0", "120,00 €", {"amount": "120.0"},
/// {"value": "120.00"}.
double? priceOf(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is Map) {
    return priceOf(v['amount'] ?? v['value'] ?? v['convertedFromValue']);
  }
  if (v is String) {
    final t = v.trim();
    final plain = double.tryParse(t);
    if (plain != null) return plain;
    return parsePrice(t.contains('€') || t.toLowerCase().contains('eur')
        ? t
        : '$t €');
  }
  return null;
}

// ---------------- Subito ----------------

/// La pagina di ricerca di Subito contiene i dati in uno script __NEXT_DATA__.
String? extractNextData(String html) {
  final m = RegExp(
          r'<script[^>]*id="__NEXT_DATA__"[^>]*>([\s\S]*?)</script>')
      .firstMatch(html);
  return m?.group(1);
}

List<RemoteItem> parseSubitoHtml(String html) {
  final raw = extractNextData(html);
  if (raw == null) {
    throw const FormatException('Subito: dati della pagina non trovati');
  }
  return parseSubitoJson(jsonDecode(raw));
}

List<RemoteItem> parseSubitoJson(dynamic data) {
  final maps = findMaps(
      data,
      (m) =>
          m['subject'] is String &&
          (m.containsKey('urls') || m.containsKey('urn')));
  final seen = <String>{};
  final out = <RemoteItem>[];
  for (final m in maps) {
    final id = str(m['urn']) ?? str(m['id']) ?? str(dig(m, ['urls', 'default']));
    if (id == null || !seen.add(id)) continue;
    out.add(RemoteItem(
      source: 'Subito',
      id: id,
      title: str(m['subject']) ?? '',
      description: str(m['body']) ?? '',
      price: _subitoPrice(m),
      url: str(dig(m, ['urls', 'default'])) ?? str(dig(m, ['urls', 'mobile'])),
      imageUrl: _subitoImage(m),
      place: str(dig(m, ['geo', 'town', 'value'])) ??
          str(dig(m, ['geo', 'city', 'value'])),
      isWatch: _subitoIsWatch(m),
      siteBrand: _subitoBrand(m),
    ));
  }
  return out;
}

double? _subitoPrice(Map<String, dynamic> m) {
  final f = m['features'];
  dynamic priceFeature;
  if (f is Map) {
    priceFeature = f['/price'];
  } else if (f is List) {
    for (final e in f) {
      if (e is Map && e['uri'] == '/price') priceFeature = e;
    }
  }
  final values = priceFeature is Map ? priceFeature['values'] : null;
  if (values is List && values.isNotEmpty && values.first is Map) {
    final first = values.first as Map;
    return priceOf(first['key']) ?? priceOf(first['value']);
  }
  return priceOf(m['price']);
}

/// Subito: marca scelta dal venditore (campo "Marca").
String? _subitoBrand(Map<String, dynamic> m) {
  final f = m['features'];
  dynamic values;
  if (f is Map) {
    values = dig(f, ['/fashion/brand', 'values']) ?? dig(f, ['/brand', 'values']);
  } else if (f is List) {
    for (final e in f) {
      if (e is Map && '${e['uri']}'.endsWith('/brand')) values = e['values'];
    }
  }
  if (values is List && values.isNotEmpty) return str(dig(values.first, ['value']));
  return null;
}

/// Subito: categoria 16 (Abbigliamento e Accessori) con tipologia
/// "Orologi e gioielli" (chiave 12).
bool? _subitoIsWatch(Map<String, dynamic> m) {
  final cat = str(dig(m, ['category', 'id']));
  if (cat != null && cat != '16') return false;
  final f = m['features'];
  final types = <dynamic>[];
  if (f is Map) {
    for (final k in ['/clothing_type', '/fashion/clothing_type']) {
      final v = dig(f, [k, 'values']);
      if (v is List) types.addAll(v);
    }
  } else if (f is List) {
    for (final e in f) {
      if (e is Map && '${e['uri']}'.contains('clothing_type') && e['values'] is List) {
        types.addAll(e['values'] as List);
      }
    }
  }
  if (types.isEmpty) return null;
  return types.any((t) =>
      t is Map &&
      (str(t['key']) == '12' ||
          (str(t['value']) ?? '').toLowerCase().contains('orolog')));
}

String? _subitoImage(Map<String, dynamic> m) {
  final imgs = m['images'];
  if (imgs is! List || imgs.isEmpty) return null;
  final first = imgs.first;
  final base = str(dig(first, ['cdnBaseUrl'])) ?? str(dig(first, ['url']));
  if (base != null) return base;
  final scale = dig(first, ['scale']);
  if (scale is List && scale.isNotEmpty) return str(dig(scale.last, ['uri']));
  return null;
}

// ---------------- eBay (API ufficiale Browse) ----------------

List<RemoteItem> parseEbay(dynamic data) {
  final items = dig(data, ['itemSummaries']);
  if (items == null) return const []; // nessun risultato
  if (items is! List) {
    throw const FormatException('eBay: risposta inattesa');
  }
  return [
    for (final e in items)
      if (e is Map && str(e['itemId']) != null)
        RemoteItem(
          source: 'eBay',
          id: str(e['itemId'])!,
          title: str(e['title']) ?? '',
          description: [
            str(e['condition']),
            if (dig(e, ['buyingOptions']) is List &&
                (dig(e, ['buyingOptions']) as List).contains('AUCTION'))
              'asta',
          ].whereType<String>().join(' · '),
          price: priceOf(e['price']),
          url: str(e['itemWebUrl']),
          imageUrl: str(dig(e, ['image', 'imageUrl'])),
          place: str(dig(e, ['itemLocation', 'city'])),
          isWatch: _ebayIsWatch(e),
        ),
  ];
}

bool? _ebayIsWatch(Map e) {
  final cats = e['categories'];
  if (cats is! List || cats.isEmpty) return null;
  return cats.any((c) =>
          c is Map &&
          (str(c['categoryId']) == '31387' ||
              (str(c['categoryName']) ?? '').toLowerCase().contains('orologi da polso')))
      ? true
      : null;
}
