import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/catalog.dart';
import '../core/models.dart';
import '../core/valuator.dart';

/// Siti su cui l'app sa cercare da sola.
const searchSites = ['Subito', 'eBay'];

const defaultBrands = {'seiko'};

/// Esito dell'ultima ricerca su un sito.
class SiteStatus {
  final DateTime at;
  final bool ok;
  final int found;
  final int fresh;
  final String? error;

  const SiteStatus(
      {required this.at,
      required this.ok,
      this.found = 0,
      this.fresh = 0,
      this.error});

  Map<String, dynamic> toJson() => {
        't': at.millisecondsSinceEpoch,
        'ok': ok,
        'n': found,
        'f': fresh,
        if (error != null) 'e': error,
      };

  factory SiteStatus.fromJson(Map<String, dynamic> j) => SiteStatus(
        at: DateTime.fromMillisecondsSinceEpoch((j['t'] as num?)?.toInt() ?? 0),
        ok: j['ok'] as bool? ?? false,
        found: (j['n'] as num?)?.toInt() ?? 0,
        fresh: (j['f'] as num?)?.toInt() ?? 0,
        error: j['e'] as String?,
      );
}

/// Salva annunci, storico prezzi e impostazioni sul telefono.
/// L'app e il controllo in sottofondo girano separati: prima di leggere
/// o scrivere, chiamare [reload].
class Store {
  static const _kListings = 'listings_v1';
  static const _kHistory = 'history_v1';
  static const _kThreshold = 'threshold_v1';
  static const _kAlerts = 'alerts_v1';
  static const _kAuto = 'auto_v1';
  static const _kInterval = 'interval_v1';
  static const _kBrands = 'brands_v1';
  static const _kExtras = 'extras_v1';
  static const _kMisspell = 'misspell_v1';
  static const _kSites = 'sites_v1';
  static const _kEbayId = 'ebay_id_v1';
  static const _kEbayCert = 'ebay_cert_v1';
  static const _kStatus = 'status_v1';
  static const _kLastRun = 'last_run_v1';
  static const maxListings = 800;
  static const maxHistory = 4000;

  final SharedPreferences _prefs;
  Store._(this._prefs);

  static Future<Store> open() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return Store._(p);
  }

  Future<void> reload() => _prefs.reload();

  // ---- annunci e storico ----
  List<Listing> loadListings() =>
      _decodeList(_kListings).map(Listing.fromJson).toList();

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

  // ---- valutazione e avvisi ----
  Settings loadSettings() =>
      Settings(dealThreshold: _prefs.getDouble(_kThreshold) ?? 0.25);
  Future<void> saveThreshold(double v) => _prefs.setDouble(_kThreshold, v);

  bool get alertsOn => _prefs.getBool(_kAlerts) ?? true;
  Future<void> setAlertsOn(bool v) => _prefs.setBool(_kAlerts, v);

  // ---- ricerca automatica ----
  bool get autoOn => _prefs.getBool(_kAuto) ?? false;
  Future<void> setAutoOn(bool v) => _prefs.setBool(_kAuto, v);

  int get intervalMinutes => _prefs.getInt(_kInterval) ?? 30;
  Future<void> setInterval(int m) => _prefs.setInt(_kInterval, m);

  /// Marche seguite (id del catalogo).
  Set<String> get enabledBrands =>
      (_prefs.getStringList(_kBrands) ?? defaultBrands.toList()).toSet();
  Future<void> setEnabledBrands(Set<String> b) =>
      _prefs.setStringList(_kBrands, b.toList());

  /// Parole di ricerca aggiunte a mano (es. "speedmaster", "skx").
  List<String> get extraQueries => _prefs.getStringList(_kExtras) ?? const [];
  Future<void> setExtraQueries(List<String> q) =>
      _prefs.setStringList(_kExtras, q);

  /// Cerca anche i nomi scritti male (es. "seico").
  bool get searchMisspellings => _prefs.getBool(_kMisspell) ?? true;
  Future<void> setSearchMisspellings(bool v) => _prefs.setBool(_kMisspell, v);

  /// Tutte le parole da cercare: marche seguite, errori comuni, parole extra.
  List<String> get queries {
    final out = <String>[];
    for (final b in brands) {
      if (!enabledBrands.contains(b.id)) continue;
      out.add(b.names.first);
      if (searchMisspellings) out.addAll(b.misspellings.take(2));
    }
    for (final q in extraQueries) {
      if (!out.contains(q)) out.add(q);
    }
    return out;
  }

  Set<String> get sites =>
      (_prefs.getStringList(_kSites) ?? const ['Subito']).toSet();
  Future<void> setSites(Set<String> s) =>
      _prefs.setStringList(_kSites, s.toList());

  String get ebayAppId => _prefs.getString(_kEbayId) ?? '';
  String get ebayCertId => _prefs.getString(_kEbayCert) ?? '';
  Future<void> setEbayKeys(String id, String cert) async {
    await _prefs.setString(_kEbayId, id.trim());
    await _prefs.setString(_kEbayCert, cert.trim());
  }

  Map<String, SiteStatus> get statuses {
    final raw = _prefs.getString(_kStatus);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) =>
          MapEntry(k, SiteStatus.fromJson(Map<String, dynamic>.from(v as Map))));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveStatuses(Map<String, SiteStatus> s) => _prefs.setString(
      _kStatus, jsonEncode(s.map((k, v) => MapEntry(k, v.toJson()))));

  DateTime? get lastRun {
    final t = _prefs.getInt(_kLastRun);
    return t == null ? null : DateTime.fromMillisecondsSinceEpoch(t);
  }

  Future<void> setLastRun(DateTime t) =>
      _prefs.setInt(_kLastRun, t.millisecondsSinceEpoch);

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
