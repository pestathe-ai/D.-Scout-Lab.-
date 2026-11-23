// Verifica il filtro per categoria di Wallapop.
import 'dart:convert';
import 'dart:io';

import '../../lib/core/http_search.dart';
import '../../lib/core/parsers.dart';

String esc(String s) =>
    s.replaceAll('%', '%25').replaceAll('\r', '').replaceAll('\n', '%0A');

Future<void> main() async {
  final c = HttpClient()..userAgent = userAgent;
  for (final extra in [
    {'category_ids': '10086'},
    {'category_id': '10086'},
    {'category_ids': '18000', 'subcategory_ids': '10086'},
    {'category_ids': '12465', 'subcategory_ids': '9562'},
  ]) {
    final rq = await c.getUrl(Uri.https('api.wallapop.com', '/api/v3/search', {
      'keywords': 'omega', 'source': 'search_box', 'order_by': 'newest',
      'latitude': '41.9028', 'longitude': '12.4964', ...extra}));
    rq.headers.set('X-DeviceOS', '0');
    final r = await rq.close();
    final body = await r.transform(utf8.decoder).join();
    var summary = 'status ${r.statusCode}';
    try {
      final items = findMaps(jsonDecode(body), (m) => m['title'] is String && m['web_slug'] is String);
      final tax = items.map((m) => (m['taxonomy'] as List?)?.map((t) => '${t['id']}:${t['name']}').join('>') ?? '').toList();
      summary += ' items ${items.length}\n${tax.take(12).join('\n')}\n${items.take(6).map((m) => m['title']).join(' | ')}';
    } catch (e) {
      summary += ' ${body.length > 200 ? body.substring(0, 200) : body}';
    }
    print('::notice title=wallapop $extra::${esc(summary)}');
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  c.close(force: true);
}
