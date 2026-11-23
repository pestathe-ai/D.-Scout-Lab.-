import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../core/http_search.dart';
import '../core/parsers.dart';
import '../core/remote_listing.dart';
import 'scout.dart';
import 'store.dart';

const _taskName = 'scout-search';
const _uniqueName = 'scout-search-periodic';

/// Esegue una ricerca su tutti i siti attivi e per tutte le parole salvate.
/// Pausa di qualche secondo tra una richiesta e l'altra: ritmo umano.
Future<int> runSearch(Scout scout, {void Function(String)? onProgress}) async {
  final store = scout.store;
  await store.reload();
  final sites = store.sites;
  final queries = store.queries;
  final keys = EbayKeys(store.ebayAppId, store.ebayCertId);
  final statuses = store.statuses;
  final searcher = SiteSearcher();
  final rnd = Random();
  var totalNew = 0;
  try {
    for (final site in searchSites) {
      if (!sites.contains(site)) continue;
      var found = 0;
      var fresh = 0;
      String? error;
      for (final q in queries) {
        onProgress?.call('$site: "$q"');
        try {
          final List<RemoteItem> items = switch (site) {
            'Subito' => await searcher.subito(q),
            'Wallapop' => await searcher.wallapop(q),
            'eBay' => await searcher.ebay(q, keys),
            _ => const <RemoteItem>[],
          };
          final watches = items.where(acceptRemote).toList();
          found += watches.length;
          final now = DateTime.now();
          final added = await scout.ingestAll(
              [for (final i in watches) listingFromRemote(i, at: now)]);
          fresh += added.length;
        } on SearchError catch (e) {
          error = e.toString();
          // Se il sito blocca, non insistere con le altre parole.
          if (e.status == 403 || e.status == 429) break;
          if (site == 'eBay' && e.status == null) break; // chiavi mancanti
        } catch (e) {
          error = 'Errore di rete: ${e.runtimeType}';
        }
        await Future<void>.delayed(
            Duration(milliseconds: 2000 + rnd.nextInt(2500)));
      }
      totalNew += fresh;
      statuses[site] = SiteStatus(
        at: DateTime.now(),
        ok: error == null || found > 0,
        found: found,
        fresh: fresh,
        error: error,
      );
      await store.saveStatuses(statuses);
    }
    await store.setLastRun(DateTime.now());
  } finally {
    searcher.close();
  }
  scout.changed();
  return totalNew;
}

/// Punto d'ingresso del controllo in sottofondo (Android WorkManager).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final scout = await Scout.create();
      if (!scout.store.autoOn) return true;
      await runSearch(scout);
    } catch (_) {
      // Riprova al prossimo giro.
    }
    return true;
  });
}

class AutoSearch {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await Workmanager().initialize(callbackDispatcher);
    _initialized = true;
  }

  /// Programma (o annulla) il controllo periodico secondo le impostazioni.
  static Future<void> schedule(Store store) async {
    await init();
    if (!store.autoOn) {
      await Workmanager().cancelByUniqueName(_uniqueName);
      return;
    }
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      _taskName,
      frequency: Duration(minutes: store.intervalMinutes),
      initialDelay: const Duration(minutes: 1),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }
}
