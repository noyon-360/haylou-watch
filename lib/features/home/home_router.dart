import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/saved_device.dart';
import '../device/device_screen.dart';
import '../scan/scan_screen.dart';

/// No saved watch -> scan screen. Saved watch -> device screen (auto-connects).
class HomeRouter extends ConsumerWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedDeviceProvider);
    return switch (saved) {
      AsyncData(:final value) => value == null
          ? const ScanScreen()
          : DeviceScreen(key: ValueKey(value.id), device: value),
      AsyncError(:final error) =>
        Scaffold(body: Center(child: Text('Could not load settings: $error'))),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}
