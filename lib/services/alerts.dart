import 'package:flutter/services.dart';

/// Funzioni native dell'app (MainActivity.kt): permessi, link, batteria.
class AppNative {
  static const _ch = MethodChannel('scout_lab/app');

  static Future<T?> _call<T>(String m, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(m, args);
    } on PlatformException catch (_) {
      return null;
    } on MissingPluginException catch (_) {
      return null;
    }
  }

  static Future<void> requestNotificationPermission() =>
      _call<void>('requestPermission');

  static Future<bool> openUrl(String url) async =>
      await _call<bool>('openUrl', {'url': url}) ?? false;

  /// Vero se Android non limita l'app in sottofondo.
  static Future<bool> batteryUnrestricted() async =>
      await _call<bool>('batteryUnrestricted') ?? false;

  static Future<void> requestBatteryExemption() =>
      _call<void>('requestBatteryExemption');
}
