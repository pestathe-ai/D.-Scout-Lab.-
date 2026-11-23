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
    final names = r1.cookies.map((k) => k.name).join(',');
    final req2 = await c.getUrl(Uri.https('www.vinted.it', '/api/v2/catalog/items', {'search_text': q, 'per_page': '5'}));
    req2.headers.set('Cookie', r1.cookies.map((k) => '${k.name}=${k.value}').join('; '));
    req2.headers.set('Accept', 'application/json');
    final r2 = await req2.close();
    final b2 = await r2.transform(const SystemEncoding().decoder).join();
    print('::notice title=vinted diag::${esc('home ${r1.statusCode} len ${b1.length} cookies [$names]\napi ${r2.statusCode} ${r2.headers.value('server')} ${b2.length > 300 ? b2.substring(0, 300) : b2}')}');
  } catch (e) {
    print('::warning title=vinted diag::${esc('$e')}');
  }
  c.close(force: true);
  s.close();
}
