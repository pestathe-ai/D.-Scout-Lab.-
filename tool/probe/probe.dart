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
  await run('Wallapop', () => s.wallapop(q));
  final id = Platform.environment['EBAY_APP_ID'] ?? '';
  final cert = Platform.environment['EBAY_CERT_ID'] ?? '';
  if (id.isNotEmpty) await run('eBay', () => s.ebay(q, EbayKeys(id, cert)));
  s.close();
}
