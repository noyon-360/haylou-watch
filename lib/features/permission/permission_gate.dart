import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions.dart';
import '../../platform/native_bridge.dart';
import '../../ui/kit.dart';
import '../home/splash.dart';
import 'permission_providers.dart';

/// Shows [child] only when Nearby-devices permission is granted AND Bluetooth is on.
class PermissionGate extends ConsumerWidget {
  const PermissionGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(blePermissionProvider);

    // `.value` keeps the last result while re-checking, so the screen doesn't flash.
    final result = permission.value;
    if (result == null) {
      if (permission.hasError) {
        return _CenteredMessage(
          icon: Icons.error_outline_rounded,
          danger: true,
          title: 'Could not check permissions',
          text: '${permission.error}',
          primary: ('Retry', () => ref.invalidate(blePermissionProvider)),
        );
      }
      return const SplashView();
    }

    return switch (result) {
      BlePermissionResult.granted => _BluetoothGate(child: child),
      BlePermissionResult.denied => _PermissionScreen(onAllow: () => ref.read(blePermissionProvider.notifier).request()),
      BlePermissionResult.permanentlyDenied => _PermissionScreen(
          blocked: true,
          onAllow: BlePermissions.openSettings,
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
      null || BluetoothAdapterState.unknown => const SplashView(message: 'Checking Bluetooth…'),
      _ => _CenteredMessage(
          icon: Icons.bluetooth_disabled_rounded,
          danger: true,
          title: 'Bluetooth is off',
          text: 'Turn it on to reconnect to your Haylou Smart Watch 2. Your data stays on this phone.',
          primary: ('Turn on Bluetooth', FlutterBluePlus.turnOn), // Android only
          secondary: ('Open Bluetooth settings', NativeBridge.instance.openBluetoothSettings),
        ),
    };
  }
}

/// Figma "02 Permission — Nearby devices".
class _PermissionScreen extends StatelessWidget {
  const _PermissionScreen({required this.onAllow, this.blocked = false});
  final VoidCallback onAllow;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget line(bool ok, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            IconChip(
              icon: ok ? Icons.check_rounded : Icons.close_rounded,
              size: 26,
              iconSize: 15,
              background: ok ? c.soft : c.subtle,
              foreground: ok ? c.primary : c.muted,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.text))),
          ]),
        );

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconChip(icon: Icons.bluetooth_rounded, size: 72, iconSize: 32),
              const SizedBox(height: 18),
              Text('Allow nearby devices', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 10),
              Text(
                blocked
                    ? 'The permission was denied. Turn it on in Settings → Permissions → Nearby devices.'
                    : 'This is the only permission needed to find and talk to your watch over Bluetooth.',
                style: TextStyle(fontSize: 15, height: 1.45, color: c.muted),
              ),
              const SizedBox(height: 18),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WHAT THIS APP CAN AND CAN’T DO',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.muted)),
                    const SizedBox(height: 6),
                    line(true, 'Find and connect to your watch'),
                    line(true, 'Send the alerts you choose'),
                    line(false, 'No location, contacts, SMS or call log'),
                    line(false, 'No internet, account or analytics'),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: onAllow, child: Text(blocked ? 'Open Settings' : 'Allow')),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text('You can revoke this anytime in Android settings.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma "03 Bluetooth off" style: centred icon, title, text, actions at the bottom.
class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.text,
    required this.primary,
    this.secondary,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final (String, VoidCallback) primary;
  final (String, VoidCallback)? secondary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconChip(
                      icon: icon,
                      size: 88,
                      iconSize: 38,
                      background: danger ? c.dangerSoft : c.soft,
                      foreground: danger ? c.danger : c.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.text)),
                    const SizedBox(height: 10),
                    Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.45, color: c.muted)),
                  ],
                ),
              ),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: primary.$2, child: Text(primary.$1))),
              if (secondary != null) ...[
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: OutlinedButton(onPressed: secondary!.$2, child: Text(secondary!.$1))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
