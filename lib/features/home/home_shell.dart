import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/saved_device.dart';
import '../../ui/kit.dart';
import '../device/device_screen.dart';
import '../device/find_phone_overlay.dart';
import '../device/watch_controller.dart';
import '../health/health_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';

/// Selected bottom tab. UI-only state, but kept in a provider so other screens
/// (e.g. the toast's "View" action) can switch tabs.
final homeTabProvider = NotifierProvider<HomeTab, int>(HomeTab.new);

class HomeTab extends Notifier<int> {
  @override
  int build() => 0;
  void select(int i) => state = i;
}

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.device});
  final SavedDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(homeTabProvider);
    final finding = ref.watch(watchControllerProvider.select((w) => w.findingPhone));
    final c = context.c;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: c.canvas,
          body: IndexedStack(
            index: tab,
            children: [
              DeviceScreen(device: device),
              const HealthScreen(),
              const SettingsScreen(),
              const NotificationsScreen(),
            ],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
            child: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: ref.read(homeTabProvider.notifier).select,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.watch_outlined), selectedIcon: Icon(Icons.watch_rounded), label: 'Watch'),
                NavigationDestination(icon: Icon(Icons.favorite_border_rounded), selectedIcon: Icon(Icons.favorite_rounded), label: 'Health'),
                NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'Settings'),
                NavigationDestination(icon: Icon(Icons.notifications_none_rounded), selectedIcon: Icon(Icons.notifications_rounded), label: 'Alerts'),
              ],
            ),
          ),
        ),
        // The watch asked to find this phone: full-screen until dismissed.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: finding ? const FindPhoneOverlay() : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
