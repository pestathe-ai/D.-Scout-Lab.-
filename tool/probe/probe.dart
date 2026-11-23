// Prova reale delle sorgenti dai server di GitHub.
// Stampa annotazioni leggibili via API (::notice / ::warning).
import 'dart:io';

import '../../lib/core/http_search.dart';
import '../../lib/core/parsers.dart';

String esc(String s) =>
    s.replaceAll('%', '%25').replaceAll('\r', '').replaceAll('\n', '%0A');

Future<void> run(String name, Future<List<RemoteItem>> Function() f) async {
  final sw = Stopwatch()..start();
  try {
    final items = await f();
    final withPrice = items.where((i) => i.price != null).length;
    final sample = items.take(4).map((i) => '- ${i.title} | ${i.price} | ${i.url}').join('\n');
    print('::notice title=probe $name::${esc('OK ${items.length} annunci ($withPrice con prezzo) in ${sw.elapsedMilliseconds} ms\n$sample')}');
  } catch (e) {
    print('::warning title=probe $name::${esc('ERRORE: $e')}');
  }
}

Future<void> main(List<String> args) async {
  final q = args.isEmpty ? 'seiko' : args.first;
  final s = SiteSearcher();
  await run('Subito', () => s.subito(q));
  await run('Vinted', () => s.vinted(q));
  await run('Wallapop', () => s.wallapop(q));
  final id = Platform.environment['EBAY_APP_ID'] ?? '';
  final cert = Platform.environment['EBAY_CERT_ID'] ?? '';
  if (id.isNotEmpty) await run('eBay', () => s.ebay(q, EbayKeys(id, cert)));
  // Diagnostica Vinted
  final c = HttpClient()..userAgent = userAgent;
  try {
    final r1 = await (await c.getUrl(Uri.https('www.vinted.it', '/'))).close();
    final b1 = await r1.transform(const SystemEncoding().decoder).join();
    final cookie = r1.cookies.where((k) => k.value.isNotEmpty).map((k) => '${k.name}=${k.value}').join('; ');
    final apis = RegExp(r'/api/v2/[A-Za-z0-9_/\-]+').allMatches(b1).map((m) => m.group(0)).toSet().take(40).join(' ');
    print('::notice title=vinted apis home::${esc(apis)}');
    final req3 = await c.getUrl(Uri.https('www.vinted.it', '/catalog', {'search_text': q, 'order': 'newest_first'}));
    req3.headers.set('Cookie', cookie);
    final r3 = await req3.close();
    final b3 = await r3.transform(const SystemEncoding().decoder).join();
    final apis3 = RegExp(r'(?:web/)?api/v\d[^"\\ ,]{0,50}').allMatches(b3).map((m) => m.group(0)).toSet().take(40).join(' | ');
    final i1 = b3.indexOf('amount');
    final i2 = b3.indexOf('seiko', b3.indexOf('self.__next_f'));
    String ctx(int i) => i < 0 ? '-' : b3.substring((i - 500).clamp(0, b3.length), (i + 500).clamp(0, b3.length));
    print('::notice title=vinted catalog page::${esc('status ${r3.statusCode} len ${b3.length} amountCount ${'amount'.allMatches(b3).length}\napis: $apis3')}');
    print('::notice title=vinted ctx amount::${esc(ctx(i1))}');
    print('::notice title=vinted ctx seiko::${esc(ctx(i2))}');
    for (final path in ['/api/v2/catalog/items', '/api/v2/items', '/api/v2/catalog/search']) {
      final rq = await c.getUrl(Uri.https('www.vinted.it', path, {'search_text': q, 'per_page': '5'}));
      rq.headers.set('Cookie', cookie);
      rq.headers.set('Accept', 'application/json, text/plain, */*');
      final rr = await rq.close();
      final bb = await rr.transform(const SystemEncoding().decoder).join();
      print('::notice title=vinted try $path::${esc('${rr.statusCode} ${bb.length > 200 ? bb.substring(0, 200) : bb}')}');
    }
  } catch (e) {
    print('::warning title=vinted diag::${esc('$e')}');
  }
  c.close(force: true);
  s.close();
}
