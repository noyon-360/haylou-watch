import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions.dart';

/// Nearby-devices (scan + connect) permission state.
final blePermissionProvider =
    AsyncNotifierProvider<BlePermissionNotifier, BlePermissionResult>(
  BlePermissionNotifier.new,
);

class BlePermissionNotifier extends AsyncNotifier<BlePermissionResult> {
  @override
  Future<BlePermissionResult> build() async {
    // Coming back from Android Settings: check again (no dialog).
    final listener = AppLifecycleListener(onResume: _recheck);
    ref.onDispose(listener.dispose);

    final current = await BlePermissions.check();
    if (current == BlePermissionResult.granted) return current;
    return BlePermissions.request(); // first launch: show the dialog once
  }

  /// Called by the "Allow" button.
  Future<void> request() async {
    state = await AsyncValue.guard(BlePermissions.request);
  }

  // Only *checks*. Never re-requests here, otherwise closing the
  // permission dialog (which counts as a resume) would show it again in a loop.
  Future<void> _recheck() async {
    state = await AsyncValue.guard(BlePermissions.check);
  }
}

/// Bluetooth on/off, live.
final bluetoothAdapterProvider = StreamProvider<BluetoothAdapterState>(
  (ref) => FlutterBluePlus.adapterState,
);
