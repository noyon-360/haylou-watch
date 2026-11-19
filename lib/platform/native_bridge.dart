import 'dart:async';

import 'package:flutter/services.dart';

/// A notification posted on the phone (only allow-listed apps and, if
/// enabled, incoming calls ever reach Dart — filtering happens in Kotlin).
class PhoneNotification {
  PhoneNotification.fromMap(Map<Object?, Object?> m)
      : key = m['key'] as String? ?? '',
        package = m['package'] as String? ?? '',
        title = m['title'] as String? ?? '',
        text = m['text'] as String? ?? '',
        isCall = m['isCall'] as bool? ?? false,
        callActive = m['callActive'] as bool? ?? false,
        removed = m['removed'] as bool? ?? false;

  final String key;
  final String package;
  final String title;
  final String text;
  final bool isCall;

  /// Call was answered (notification shows a running timer).
  final bool callActive;
  final bool removed;
}

class InstalledApp {
  const InstalledApp(this.package, this.label);
  final String package;
  final String label;
}

/// Talks to our own Kotlin code in android/app/src/main/kotlin/.
/// No third-party SDKs, no network.
class NativeBridge {
  NativeBridge._() {
    _channel.setMethodCallHandler(_onCall);
  }
  static final NativeBridge instance = NativeBridge._();

  static const _channel = MethodChannel('watch/native');

  final _notifications = StreamController<PhoneNotification>.broadcast();
  Stream<PhoneNotification> get notifications => _notifications.stream;

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'notification') {
      _notifications.add(PhoneNotification.fromMap(call.arguments as Map<Object?, Object?>));
    }
    return null;
  }

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // tests / non-Android
    }
  }

  /// Foreground service that keeps the BLE link alive with the app closed.
  Future<void> startService(String text) => _invoke('startService', {'text': text});
  Future<void> stopService() => _invoke('stopService');

  Future<bool> isListenerEnabled() async => await _invoke<bool>('isListenerEnabled') ?? false;
  Future<void> openListenerSettings() => _invoke('openListenerSettings');

  /// Which notifications Kotlin may hand to Dart. Everything else is dropped
  /// inside the listener service without being read.
  Future<void> setForwarding({required Set<String> apps, required bool calls}) =>
      _invoke('setForwarding', {'apps': apps.toList(), 'calls': calls});

  Future<List<InstalledApp>> launchableApps() async {
    final list = await _invoke<List<Object?>>('launchableApps') ?? const [];
    return [
      for (final e in list.cast<Map<Object?, Object?>>())
        InstalledApp(e['package'] as String, e['label'] as String),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  /// Find my phone: play the alarm sound (stops by itself after 30 s).
  Future<void> ring(bool on) => _invoke('ring', {'on': on});
}
