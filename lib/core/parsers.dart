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

  const RemoteItem({
    required this.source,
    required this.id,
    required this.title,
    this.description = '',
    this.price,
    this.url,
    this.imageUrl,
    this.place,
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

// ---------------- Vinted ----------------

List<RemoteItem> parseVinted(dynamic data, {String host = 'www.vinted.it'}) {
  final items = dig(data, ['items']);
  if (items is! List) {
    throw const FormatException('Vinted: risposta senza "items"');
  }
  return [
    for (final e in items)
      if (e is Map && str(e['id']) != null)
        RemoteItem(
          source: 'Vinted',
          id: str(e['id'])!,
          title: [str(e['title']), str(e['brand_title'])]
              .whereType<String>()
              .join(' · '),
          description: [str(e['size_title']), str(e['status'])]
              .whereType<String>()
              .join(' · '),
          price: priceOf(e['price']),
          url: str(e['url']) ?? 'https://$host/items/${e['id']}',
          imageUrl: str(dig(e, ['photo', 'url'])),
        ),
  ];
}

// ---------------- Wallapop ----------------

List<RemoteItem> parseWallapop(dynamic data) {
  final maps = findMaps(
      data,
      (m) =>
          m['title'] is String &&
          (m['web_slug'] is String ||
              (m.containsKey('id') && m.containsKey('price'))));
  final seen = <String>{};
  final out = <RemoteItem>[];
  for (final m in maps) {
    final id = str(m['id']) ?? str(m['web_slug']);
    if (id == null || !seen.add(id)) continue;
    final slug = str(m['web_slug']);
    out.add(RemoteItem(
      source: 'Wallapop',
      id: id,
      title: str(m['title']) ?? '',
      description: str(m['description']) ?? '',
      price: priceOf(m['price']) ?? priceOf(m['sale_price']),
      url: slug == null ? null : 'https://it.wallapop.com/item/$slug',
      imageUrl: str(dig(m, ['images', 0, 'urls', 'medium'])) ??
          str(dig(m, ['images', 0, 'medium'])),
      place: str(dig(m, ['location', 'city'])),
    ));
  }
  return out;
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
        ),
  ];
}
