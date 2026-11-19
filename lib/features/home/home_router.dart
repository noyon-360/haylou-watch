import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_runtime.dart';
import '../../data/saved_device.dart';
import '../scan/scan_screen.dart';
import 'home_shell.dart';
import 'splash.dart';

/// No saved watch -> scan screen. Saved watch -> tabs (runtime connects).
/// Only built once permissions are granted, so it is safe to kick the runtime.
class HomeRouter extends ConsumerWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedDeviceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(appRuntimeProvider).kick());
    return switch (saved) {
      AsyncData(:final value) => value == null
          ? const ScanScreen()
          : HomeShell(key: ValueKey(value.id), device: value),
      AsyncError(:final error) => SplashView(message: 'Could not load settings: $error'),
      _ => const SplashView(),
    };
  }
}
