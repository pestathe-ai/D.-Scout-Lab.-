import 'package:flutter/services.dart';

/// Avvisi sul telefono, tramite un piccolo canale nativo (MainActivity.kt).
class Alerts {
  static const _ch = MethodChannel('scout_lab/alerts');

  static Future<void> requestPermission() async {
    try {
      await _ch.invokeMethod<void>('requestPermission');
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }

  static Future<void> show(int id, String title, String body) async {
    try {
      await _ch.invokeMethod<void>(
          'show', {'id': id, 'title': title, 'body': body});
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }
}
