import 'package:flutter/services.dart';

/// Avvisi del telefono, utilizzabili anche dal controllo in sottofondo.
class ScoutNative {
  static const _ch = MethodChannel('scout_native');

  static Future<void> notify({
    required int id,
    required String title,
    required String body,
    String? url,
  }) async {
    try {
      await _ch.invokeMethod<void>(
          'show', {'id': id, 'title': title, 'body': body, 'url': url});
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }
}
