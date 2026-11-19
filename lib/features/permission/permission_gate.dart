import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions.dart';
import 'permission_providers.dart';

/// Shows [child] only when Nearby-devices permission is granted AND Bluetooth is on.
class PermissionGate extends ConsumerWidget {
  const PermissionGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(blePermissionProvider);

    // `.value` keeps the last result while re-checking, so the screen doesn't flash a spinner.
    final result = permission.value;
    if (result == null) {
      if (permission.hasError) {
        return _Message(
          icon: Icons.error_outline,
          text: 'Could not check permissions:\n${permission.error}',
          buttonLabel: 'Retry',
          onPressed: () => ref.invalidate(blePermissionProvider),
        );
      }
      return const _Loading();
    }

    return switch (result) {
      BlePermissionResult.granted => _BluetoothGate(child: child),
      BlePermissionResult.denied => _Message(
        icon: Icons.bluetooth_searching,
        text:
            'Allow "Nearby devices" so the app can find and connect to your watch.\n'
            'No location, contacts or other data is requested.',
        buttonLabel: 'Allow',
        onPressed: () => ref.read(blePermissionProvider.notifier).request(),
      ),
      BlePermissionResult.permanentlyDenied => const _Message(
        icon: Icons.settings,
        text:
            'Nearby devices permission was denied.\n'
            'Turn it on in Settings → Permissions → Nearby devices.',
        buttonLabel: 'Open Settings',
        onPressed: BlePermissions.openSettings,
      ),
    };
  }
}

class _BluetoothGate extends ConsumerWidget {
  const _BluetoothGate({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adapter = ref.watch(bluetoothAdapterProvider).value;

    return switch (adapter) {
      BluetoothAdapterState.on => child,
      null || BluetoothAdapterState.unknown => const _Loading(),
      _ => _Message(
        icon: Icons.bluetooth_disabled,
        text: 'Bluetooth is off.',
        buttonLabel: 'Turn on Bluetooth',
        onPressed: () => FlutterBluePlus.turnOn(), // Android only
      ),
    };
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String text;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64),
              const SizedBox(height: 16),
              Text(text, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
