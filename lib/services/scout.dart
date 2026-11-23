import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:scout_native/scout_native.dart';

import '../core/models.dart';
import '../core/sources.dart';
import '../core/valuator.dart';
import 'store.dart';

class Entry {
  final Listing listing;
  final Valuation valuation;
  const Entry(this.listing, this.valuation);
}

/// Cuore dell'app: raccoglie gli annunci (notifiche e ricerca automatica),
/// li valuta, aggiorna lo storico e avvisa.
class Scout extends ChangeNotifier {
  final Store store;
  List<Listing> _listings;
  List<PricePoint> _history;
  Settings _settings;
  bool listenerGranted = false;
  bool searching = false;
  StreamSubscription<ServiceNotificationEvent>? _sub;

  Scout._(this.store, this._listings, this._history, this._settings);

  static Future<Scout> create() async {
    final store = await Store.open();
    return Scout._(
        store, store.loadListings(), store.loadHistory(), store.loadSettings());
  }

  Settings get settings => _settings;
  bool get alertsOn => store.alertsOn;
  int get historySize => _history.length;

  /// Rilegge i dati salvati (es. dopo un controllo in sottofondo).
  Future<void> refresh() async {
    await store.reload();
    _listings = store.loadListings();
    _history = store.loadHistory();
    _settings = store.loadSettings();
    notifyListeners();
  }

  Valuator get valuator {
    final map = <String, List<double>>{};
    for (final p in _history) {
      (map[p.modelId] ??= []).add(p.price);
    }
    return Valuator(
        settings: _settings, history: map, enabledBrands: store.enabledBrands);
  }

  List<Entry> get entries {
    final v = valuator;
    return [
      for (final l in _listings.reversed)
        if (!l.dismissed && l.source != 'Wallapop') Entry(l, v.evaluate(l)),
    ].where((e) => e.valuation.verdict != Verdict.nonPertinente).toList();
  }

  List<Entry> get deals => entries
      .where((e) =>
          e.valuation.verdict == Verdict.affare ||
          e.valuation.verdict == Verdict.interessante ||
          e.valuation.verdict == Verdict.daVerificare)
      .toList()
    ..sort((a, b) => b.valuation.score.compareTo(a.valuation.score));

  // ---------------- notifiche delle app di annunci ----------------

  Future<void> startListener() async {
    if (!Platform.isAndroid) return;
    listenerGranted = await NotificationListenerService.isPermissionGranted();
    notifyListeners();
    if (!listenerGranted) return;
    final active = await NotificationListenerService.getActiveNotifications();
    final batch = <Listing>[];
    for (final e in active) {
      final l = _fromEvent(e);
      if (l != null) batch.add(l);
    }
    if (batch.isNotEmpty) await ingestAll(batch, alert: false);
    _sub ??= NotificationListenerService.notificationsStream.listen((e) async {
      final l = _fromEvent(e);
      if (l != null) await ingestAll([l]);
    });
  }

  Future<void> requestListenerPermission() async {
    if (!Platform.isAndroid) return;
    await NotificationListenerService.requestPermission();
    await startListener();
  }

  Listing? _fromEvent(ServiceNotificationEvent e) {
    if (e.hasRemoved == true) return null;
    return listingFromNotification(
      packageName: e.packageName ?? '',
      title: e.title ?? '',
      content: e.content ?? '',
    );
  }

  // ---------------- raccolta e valutazione ----------------

  /// Aggiunge gli annunci nuovi, aggiorna lo storico, avvisa per gli affari.
  /// Restituisce gli annunci nuovi con la loro valutazione.
  Future<List<Entry>> ingestAll(List<Listing> items, {bool alert = true}) async {
    await store.reload();
    _listings = store.loadListings();
    _history = store.loadHistory();
    final known = {for (final l in _listings) l.id};
    final v = valuator;
    final added = <Entry>[];
    final newHistory = <PricePoint>[];
    for (final l in items) {
      if (!known.add(l.id)) continue;
      final val = v.evaluate(l);
      // Marche non seguite, non orologi, senza prezzo: non salvati.
      if (val.verdict == Verdict.nonPertinente) continue;
      added.add(Entry(l, val));
      if (val.model != null &&
          l.price != null &&
          val.verdict != Verdict.scartato) {
        newHistory.add(PricePoint(val.model!.id, l.price!, l.seenAt, l.id));
      }
    }
    if (added.isEmpty) return const [];
    _listings = [..._listings, for (final e in added) e.listing];
    await store.saveListings(_listings);
    if (newHistory.isNotEmpty) {
      _history = [..._history, ...newHistory];
      await store.saveHistory(_history);
    }
    notifyListeners();
    if (alert && store.alertsOn) {
      await _notifyDeals(added.where((e) => e.valuation.isHot).toList());
    }
    return added;
  }

  Future<void> _notifyDeals(List<Entry> hot) async {
    if (hot.isEmpty) return;
    hot.sort((a, b) => b.valuation.score.compareTo(a.valuation.score));
    if (hot.length > 3) {
      await ScoutNative.notify(
        id: 1,
        title: '${hot.length} nuovi affari',
        body: hot
            .take(5)
            .map((e) =>
                '${e.valuation.model?.name ?? e.valuation.brand?.name} · ${e.listing.price?.round()} € (${e.listing.source})')
            .join('\n'),
      );
      return;
    }
    for (final e in hot) {
      final val = e.valuation;
      final l = e.listing;
      final name = val.model?.name ?? val.brand?.name ?? 'Orologio';
      final margin =
          val.margin == null ? '' : ' · margine ~${val.margin!.round()} €';
      final where = l.place == null ? '' : ' · ${l.place}';
      await ScoutNative.notify(
        id: l.id.hashCode & 0x7fffffff,
        title: 'Affare: $name',
        body: '${l.price?.round()} € su ${l.source}$margin$where\n${l.title}',
        url: l.url,
      );
    }
  }

  Future<void> dismiss(Listing l) async {
    await store.reload();
    _listings = [
      for (final x in store.loadListings())
        x.id == l.id ? x.copyWith(dismissed: true) : x,
    ];
    await store.saveListings(_listings);
    notifyListeners();
  }

  Future<void> setThreshold(double v) async {
    _settings = Settings(
      dealThreshold: v,
      shippingCost: _settings.shippingCost,
      resaleFee: _settings.resaleFee,
    );
    await store.saveThreshold(v);
    notifyListeners();
  }

  Future<void> setAlertsOn(bool v) async {
    await store.setAlertsOn(v);
    notifyListeners();
  }

  Future<void> clearAll() async {
    _listings = [];
    await store.saveListings(_listings);
    notifyListeners();
  }

  void changed() => notifyListeners();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
