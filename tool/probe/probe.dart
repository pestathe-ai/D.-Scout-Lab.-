// Prova reale delle sorgenti dai server di GitHub.
// Stampa annotazioni leggibili via API (::notice / ::warning).
import 'dart:io';

import '../../lib/core/http_search.dart';
import '../../lib/core/parsers.dart';
import '../../lib/core/remote_listing.dart';
import '../../lib/core/valuator.dart';

String esc(String s) =>
    s.replaceAll('%', '%25').replaceAll('\r', '').replaceAll('\n', '%0A');

const v = Valuator(enabledBrands: {'seiko'});

Future<void> run(String name, Future<List<RemoteItem>> Function() f) async {
  try {
    final items = await f();
    final lines = <String>[];
    var kept = 0;
    for (final i in items) {
      final acc = acceptRemote(i);
      final val = v.evaluateText('${i.title} ${i.description}', i.price, title: i.title, siteSaysWatch: i.isWatch, siteBrand: i.siteBrand);
      final saved = acc && val.verdict != Verdict.nonPertinente;
      if (saved) kept++;
      lines.add('${saved ? 'TIENE' : 'scarta'} [${i.isWatch}] ${val.verdict.name} {${i.siteBrand}} ${i.price} | ${i.title} | ${i.description.replaceAll('\n', ' ').substring(0, i.description.length.clamp(0, 70))}');
    }
    print('::notice title=probe $name::${esc('${items.length} annunci, tenuti $kept\n${lines.join('\n')}')}');
  } catch (e) {
    print('::warning title=probe $name::${esc('ERRORE: $e')}');
  }
}

Future<void> main(List<String> args) async {
  final q = args.isEmpty ? 'seiko' : args.first;
  final s = SiteSearcher();
  await run('Subito $q', () => s.subito(q));
  final id = Platform.environment['EBAY_APP_ID'] ?? '';
  final cert = Platform.environment['EBAY_CERT_ID'] ?? '';
  if (id.isNotEmpty) await run('eBay', () => s.ebay(q, EbayKeys(id, cert)));
  s.close();
}
