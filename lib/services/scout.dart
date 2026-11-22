import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

import '../core/models.dart';
import '../core/sources.dart';
import '../core/valuator.dart';
import 'alerts.dart';
import 'store.dart';

class Entry {
  final Listing listing;
  final Valuation valuation;
  const Entry(this.listing, this.valuation);
}

/// Cuore dell'app: legge le notifiche, valuta gli annunci, avvisa.
class Scout extends ChangeNotifier {
  final Store store;
  List<Listing> _listings;
  List<PricePoint> _history;
  Settings _settings;
  bool listenerGranted = false;
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

  Valuator get valuator {
    final map = <String, List<double>>{};
    for (final p in _history) {
      (map[p.modelId] ??= []).add(p.price);
    }
    return Valuator(settings: _settings, history: map);
  }

  /// Tutti gli annunci valutati, dal più recente.
  List<Entry> get entries {
    final v = valuator;
    return [
      for (final l in _listings.reversed)
        if (!l.dismissed) Entry(l, v.evaluate(l)),
    ];
  }

  List<Entry> get deals {
    final list = entries
        .where((e) =>
            e.valuation.verdict == Verdict.affare ||
            e.valuation.verdict == Verdict.interessante ||
            e.valuation.verdict == Verdict.daVerificare)
        .toList()
      ..sort((a, b) => b.valuation.score.compareTo(a.valuation.score));
    return list;
  }

  Future<void> start() async {
    if (!Platform.isAndroid) return;
    listenerGranted = await NotificationListenerService.isPermissionGranted();
    notifyListeners();
    if (!listenerGranted) return;
    // Notifiche arrivate mentre l'app era chiusa e ancora nella tendina.
    final active = await NotificationListenerService.getActiveNotifications();
    for (final e in active) {
      await _onEvent(e, alert: false);
    }
    _sub ??= NotificationListenerService.notificationsStream.listen((e) {
      _onEvent(e, alert: true);
    });
  }

  Future<void> requestListenerPermission() async {
    if (!Platform.isAndroid) return;
    await NotificationListenerService.requestPermission();
    await start();
  }

  Future<void> _onEvent(ServiceNotificationEvent e, {required bool alert}) async {
    if (e.hasRemoved == true) return;
    final l = listingFromNotification(
      packageName: e.packageName ?? '',
      title: e.title ?? '',
      content: e.content ?? '',
    );
    if (l == null) return;
    await ingest(l, alert: alert);
  }

  /// Aggiunge un annuncio (se nuovo), aggiorna lo storico e avvisa se è un affare.
  Future<Valuation?> ingest(Listing l, {bool alert = true}) async {
    if (_listings.any((x) => x.id == l.id)) return null;
    final val = valuator.evaluate(l);
    if (val.verdict == Verdict.nonPertinente && val.brand == null) {
      return val; // non seguito: non lo salviamo
    }
    _listings = [..._listings, l];
    if (val.model != null &&
        l.price != null &&
        val.verdict != Verdict.scartato) {
      _history = [..._history, PricePoint(val.model!.id, l.price!, l.seenAt, l.id)];
      await store.saveHistory(_history);
    }
    await store.saveListings(_listings);
    notifyListeners();
    if (alert && alertsOn && val.isHot) {
      final name = val.model?.name ?? val.brand?.name ?? 'Orologio';
      final margin = val.margin == null ? '' : ' · margine ~${val.margin!.round()} €';
      await Alerts.show(
        l.id.hashCode & 0x7fffffff,
        'Affare: $name',
        '${l.price?.round()} € su ${l.source}$margin',
      );
    }
    return val;
  }

  Future<void> dismiss(Listing l) async {
    _listings = [
      for (final x in _listings) x.id == l.id ? x.copyWith(dismissed: true) : x,
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
    if (v) await Alerts.requestPermission();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _listings = [];
    await store.saveListings(_listings);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
