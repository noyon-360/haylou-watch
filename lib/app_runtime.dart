import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/permissions.dart';
import 'data/app_settings.dart';
import 'data/saved_device.dart';
import 'features/device/watch_controller.dart';
import 'features/notifications/app_types.dart';
import 'platform/native_bridge.dart';

/// Non-UI logic that must keep working while no screen is shown
/// (the Flutter engine is kept alive by the foreground service):
/// auto-connect, reconnect when Bluetooth returns, notification forwarding,
/// foreground-service text.
final appRuntimeProvider = Provider<AppRuntime>((ref) {
  final r = AppRuntime(ref);
  ref.onDispose(r.dispose);
  r.start();
  return r;
});

class AppRuntime {
  AppRuntime(this.ref);
  final Ref ref;

  final _subs = <StreamSubscription<dynamic>>[];
  final _recent = <String, DateTime>{}; // de-dup notification updates
  final _activeCalls = <String>{};
  Timer? _buzzTimer;

  /// The watch shows the call screen but doesn't vibrate by itself, so buzz
  /// every 3 s while ringing; capped at 60 s in case the end event is missed.
  void _startCallBuzz(WatchController watch) {
    _stopCallBuzz();
    var ticks = 0;
    Future<void> buzz() => watch.buzzForCall().catchError((_) {});
    buzz();
    _buzzTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (++ticks >= 20 || _activeCalls.isEmpty) {
        _stopCallBuzz();
      } else {
        buzz();
      }
    });
  }

  void _stopCallBuzz() {
    _buzzTimer?.cancel();
    _buzzTimer = null;
  }

  void start() {
    // Connect as soon as a saved watch + permission + Bluetooth are present.
    ref.listen(savedDeviceProvider, (_, next) => _maybeConnect(), fireImmediately: true);
    _subs.add(FlutterBluePlus.adapterState.listen((s) {
      if (s == BluetoothAdapterState.on) _maybeConnect();
    }));

    // Keep the Kotlin-side filter and the service in sync with settings/state.
    ref.listen(appSettingsProvider, (_, next) {
      final s = next.value;
      if (s == null) return;
      NativeBridge.instance.setForwarding(apps: s.allowedApps, calls: s.callAlerts);
      _updateService();
    }, fireImmediately: true);
    ref.listen(watchControllerProvider, (prev, next) {
      if (prev?.status != next.status || prev?.battery != next.battery) _updateService();
    });

    _subs.add(NativeBridge.instance.notifications.listen(_forward));
  }

  /// Called by the UI once permissions are granted (no dialogs from here).
  void kick() => _maybeConnect();

  Future<void> _maybeConnect() async {
    final device = ref.read(savedDeviceProvider).value;
    if (device == null) return;
    if (await BlePermissions.check() != BlePermissionResult.granted) return;
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) return;
    final c = ref.read(watchControllerProvider.notifier);
    final s = ref.read(watchControllerProvider);
    if (s.deviceId == device.id) {
      c.reconnectNow();
    } else if (!s.isBusy && !s.isReady) {
      c.connect(device.id);
    }
  }

  void _updateService() {
    final settings = ref.read(appSettingsProvider).value;
    final device = ref.read(savedDeviceProvider).value;
    final w = ref.read(watchControllerProvider);
    final wanted = settings?.background == true &&
        device != null &&
        w.status != LinkStatus.disconnected;
    if (!wanted) {
      NativeBridge.instance.stopService();
      return;
    }
    final text = switch (w.status) {
      LinkStatus.ready => 'Connected${w.battery == null ? '' : ' · battery ${w.battery}%'}',
      LinkStatus.error => 'Reconnecting…',
      _ => 'Connecting…',
    };
    NativeBridge.instance.startService(text);
  }

  Future<void> _forward(PhoneNotification n) async {
    final settings = ref.read(appSettingsProvider).value;
    final watch = ref.read(watchControllerProvider.notifier);
    if (settings == null) return;

    if (n.isCall) {
      if (!settings.callAlerts) return;
      if (n.removed || n.callActive) {
        if (_activeCalls.remove(n.key)) {
          if (_activeCalls.isEmpty) _stopCallBuzz();
          await watch.endCall();
        }
      } else if (_activeCalls.add(n.key)) {
        await watch.sendCall(n.title.isNotEmpty ? n.title : n.text);
        _startCallBuzz(watch);
      }
      return;
    }

    if (n.removed || !settings.allowedApps.contains(n.package)) return;
    if (n.title.isEmpty && n.text.isEmpty) return;

    // Apps re-post the same notification often; send each text once per minute.
    final id = '${n.key}|${n.title}|${n.text}';
    final now = DateTime.now();
    _recent.removeWhere((_, t) => now.difference(t) > const Duration(minutes: 1));
    if (_recent.containsKey(id)) return;
    _recent[id] = now;

    await watch.sendNotification(msgTypeFor(n.package), n.title, n.text);
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
  }
}
