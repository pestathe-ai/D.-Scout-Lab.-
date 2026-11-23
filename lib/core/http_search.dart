/// Ricerca diretta sui siti di annunci (solo dart:io, niente Flutter:
/// lo stesso codice gira nell'app e nel controllo automatico su GitHub).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'parsers.dart';

const userAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';

/// Errore leggibile di una sorgente.
class SearchError implements Exception {
  final String message;
  final int? status;
  const SearchError(this.message, {this.status});
  @override
  String toString() => status == null ? message : '$message (HTTP $status)';
}

class HttpResult {
  final int status;
  final String body;
  final List<Cookie> cookies;
  const HttpResult(this.status, this.body, this.cookies);
}

class EbayKeys {
  final String appId;
  final String certId;
  const EbayKeys(this.appId, this.certId);
  bool get valid => appId.trim().isNotEmpty && certId.trim().isNotEmpty;
}

/// Token eBay in memoria (si rinnova da solo).
class EbayToken {
  String? value;
  DateTime? expires;
}

class SiteSearcher {
  final HttpClient _client;
  final Duration timeout;
  final Map<String, String> _vintedCookies = {};
  final EbayToken ebayToken;

  SiteSearcher({this.timeout = const Duration(seconds: 20), EbayToken? token})
      : _client = HttpClient(),
        ebayToken = token ?? EbayToken() {
    _client.userAgent = userAgent;
    _client.connectionTimeout = timeout;
  }

  void close() => _client.close(force: true);

  Future<HttpResult> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final req = await _client.openUrl(method, uri).timeout(timeout);
    req.followRedirects = true;
    req.headers.set(HttpHeaders.acceptLanguageHeader, 'it-IT,it;q=0.9');
    headers.forEach(req.headers.set);
    if (body != null) req.write(body);
    final res = await req.close().timeout(timeout);
    final text = await res
        .transform(const Utf8Decoder(allowMalformed: true))
        .join()
        .timeout(timeout);
    return HttpResult(res.statusCode, text, res.cookies);
  }

  dynamic _json(HttpResult r, String site) {
    if (r.status == 403 || r.status == 429) {
      throw SearchError('$site ha bloccato la richiesta, riprovo più tardi',
          status: r.status);
    }
    if (r.status != 200) {
      throw SearchError('$site non ha risposto bene', status: r.status);
    }
    try {
      return jsonDecode(r.body);
    } on FormatException {
      throw SearchError('$site ha risposto con una pagina inattesa',
          status: r.status);
    }
  }

  // ---------- Subito ----------
  Future<List<RemoteItem>> subito(String query) async {
    final uri = Uri.https('www.subito.it', '/annunci-italia/vendita/usato/',
        {'q': query, 'order': 'datedesc'});
    final r = await _send('GET', uri, headers: {
      HttpHeaders.acceptHeader: 'text/html,application/xhtml+xml',
    });
    if (r.status == 403 || r.status == 429) {
      throw SearchError('Subito ha bloccato la richiesta, riprovo più tardi',
          status: r.status);
    }
    if (r.status != 200) {
      throw SearchError('Subito non ha risposto bene', status: r.status);
    }
    try {
      return parseSubitoHtml(r.body);
    } on FormatException catch (e) {
      throw SearchError(e.message, status: r.status);
    }
  }

  // ---------- Vinted ----------
  Future<void> _vintedSession() async {
    final r = await _send('GET', Uri.https('www.vinted.it', '/'), headers: {
      HttpHeaders.acceptHeader: 'text/html',
    });
    for (final c in r.cookies) {
      _vintedCookies[c.name] = c.value;
    }
  }

  Future<List<RemoteItem>> vinted(String query) async {
    if (_vintedCookies.isEmpty) await _vintedSession();
    Future<HttpResult> call() => _send(
          'GET',
          Uri.https('www.vinted.it', '/api/v2/catalog/items', {
            'search_text': query,
            'order': 'newest_first',
            'per_page': '48',
            'page': '1',
          }),
          headers: {
            HttpHeaders.acceptHeader: 'application/json',
            HttpHeaders.cookieHeader:
                _vintedCookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
          },
        );
    var r = await call();
    if (r.status == 401) {
      _vintedCookies.clear();
      await _vintedSession();
      r = await call();
    }
    try {
      return parseVinted(_json(r, 'Vinted'));
    } on FormatException catch (e) {
      throw SearchError(e.message, status: r.status);
    }
  }

  // ---------- Wallapop ----------
  Future<List<RemoteItem>> wallapop(String query,
      {double lat = 41.9028, double lng = 12.4964}) async {
    final r = await _send(
      'GET',
      Uri.https('api.wallapop.com', '/api/v3/search', {
        'keywords': query,
        'source': 'search_box',
        'order_by': 'newest',
        'latitude': '$lat',
        'longitude': '$lng',
      }),
      headers: {
        HttpHeaders.acceptHeader: 'application/json',
        'X-DeviceOS': '0',
        'Origin': 'https://it.wallapop.com',
        'Referer': 'https://it.wallapop.com/',
      },
    );
    try {
      return parseWallapop(_json(r, 'Wallapop'));
    } on FormatException catch (e) {
      throw SearchError(e.message, status: r.status);
    }
  }

  // ---------- eBay (API ufficiale) ----------
  Future<String> _ebayAuth(EbayKeys keys) async {
    final now = DateTime.now();
    if (ebayToken.value != null &&
        ebayToken.expires != null &&
        now.isBefore(ebayToken.expires!)) {
      return ebayToken.value!;
    }
    final basic =
        base64Encode(utf8.encode('${keys.appId.trim()}:${keys.certId.trim()}'));
    final r = await _send(
      'POST',
      Uri.https('api.ebay.com', '/identity/v1/oauth2/token'),
      headers: {
        HttpHeaders.authorizationHeader: 'Basic $basic',
        HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials&scope='
          '${Uri.encodeQueryComponent('https://api.ebay.com/oauth/api_scope')}',
    );
    if (r.status == 401 || r.status == 400) {
      throw SearchError('eBay: chiavi non valide, controllale', status: r.status);
    }
    final data = _json(r, 'eBay');
    final token = data is Map ? data['access_token'] as String? : null;
    if (token == null) throw const SearchError('eBay: token non ricevuto');
    final secs = data is Map ? (data['expires_in'] as num?)?.toInt() ?? 7200 : 7200;
    ebayToken.value = token;
    ebayToken.expires = now.add(Duration(seconds: secs - 120));
    return token;
  }

  Future<List<RemoteItem>> ebay(String query, EbayKeys keys) async {
    if (!keys.valid) {
      throw const SearchError('eBay: inserisci le chiavi nelle Impostazioni');
    }
    final token = await _ebayAuth(keys);
    Future<HttpResult> call({bool withCategory = true}) => _send(
          'GET',
          Uri.https('api.ebay.com', '/buy/browse/v1/item_summary/search', {
            'q': query,
            if (withCategory) 'category_ids': '31387',
            'sort': 'newlyListed',
            'limit': '50',
            'filter': 'buyingOptions:{FIXED_PRICE|BEST_OFFER},priceCurrency:EUR',
          }),
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            'X-EBAY-C-MARKETPLACE-ID': 'EBAY_IT',
            HttpHeaders.acceptHeader: 'application/json',
          },
        );
    var r = await call();
    if (r.status == 400) r = await call(withCategory: false);
    if (r.status == 401) {
      ebayToken.value = null;
      throw const SearchError('eBay: accesso scaduto, riprovo al prossimo giro');
    }
    try {
      var items = parseEbay(_json(r, 'eBay'));
      if (items.isEmpty) {
        final r2 = await call(withCategory: false);
        if (r2.status == 200) items = parseEbay(_json(r2, 'eBay'));
      }
      return items;
    } on FormatException catch (e) {
      throw SearchError(e.message, status: r.status);
    }
  }
}
