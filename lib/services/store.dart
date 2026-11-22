import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';
import '../core/valuator.dart';

/// Salva annunci, storico prezzi e impostazioni sul telefono.
class Store {
  static const _kListings = 'listings_v1';
  static const _kHistory = 'history_v1';
  static const _kThreshold = 'threshold_v1';
  static const _kAlerts = 'alerts_v1';
  static const maxListings = 600;
  static const maxHistory = 3000;

  final SharedPreferences _prefs;
  Store._(this._prefs);

  static Future<Store> open() async =>
      Store._(await SharedPreferences.getInstance());

  List<Listing> loadListings() => _decodeList(_kListings)
      .map(Listing.fromJson)
      .toList();

  Future<void> saveListings(List<Listing> items) async {
    final trimmed = items.length > maxListings
        ? items.sublist(items.length - maxListings)
        : items;
    await _prefs.setString(
        _kListings, jsonEncode([for (final l in trimmed) l.toJson()]));
  }

  List<PricePoint> loadHistory() =>
      _decodeList(_kHistory).map(PricePoint.fromJson).toList();

  Future<void> saveHistory(List<PricePoint> items) async {
    final trimmed = items.length > maxHistory
        ? items.sublist(items.length - maxHistory)
        : items;
    await _prefs.setString(
        _kHistory, jsonEncode([for (final p in trimmed) p.toJson()]));
  }

  Settings loadSettings() =>
      Settings(dealThreshold: _prefs.getDouble(_kThreshold) ?? 0.25);

  Future<void> saveThreshold(double v) => _prefs.setDouble(_kThreshold, v);

  bool get alertsOn => _prefs.getBool(_kAlerts) ?? true;
  Future<void> setAlertsOn(bool v) => _prefs.setBool(_kAlerts, v);

  List<Map<String, dynamic>> _decodeList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      return [for (final e in data) if (e is Map) Map<String, dynamic>.from(e)];
    } catch (_) {
      return const [];
    }
  }
}
