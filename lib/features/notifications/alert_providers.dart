import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/native_bridge.dart';
import '../../ui/kit.dart';

/// Is our NotificationListenerService enabled? Re-checked when the user
/// comes back from Android's settings screen.
final listenerEnabledProvider = FutureProvider.autoDispose<bool>((ref) {
  final l = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(l.dispose);
  return NativeBridge.instance.isListenerEnabled();
});

/// Apps with a launcher icon (labels only; no icons or other data are read).
final installedAppsProvider = FutureProvider<List<InstalledApp>>((_) => NativeBridge.instance.launchableApps());

/// Label for a package, falling back to the package name (e.g. uninstalled).
String appLabel(List<InstalledApp>? apps, String package) =>
    apps?.where((a) => a.package == package).firstOrNull?.label ?? package;

/// Calm, stable letter tile per app (Figma "avatar").
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.label, required this.package, this.size = 38});
  final String label;
  final String package;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hue = (package.hashCode % 360).abs().toDouble();
    final tint = HSLColor.fromAHSL(1, hue, 0.38, 0.42).toColor();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(size * 0.32)),
      child: Text(label.isEmpty ? '?' : label.characters.first.toUpperCase(),
          style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w700, color: tint)),
    );
  }
}

/// "Notification access is on/off" card (overview + picker).
class ListenerStatusCard extends ConsumerWidget {
  const ListenerStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final enabled = ref.watch(listenerEnabledProvider).value ?? false;
    return SurfaceCard(
      child: Row(children: [
        IconChip(
          icon: enabled ? Icons.check_rounded : Icons.notifications_off_outlined,
          size: 36,
          iconSize: 18,
          background: enabled ? c.success : c.dangerSoft,
          foreground: enabled ? Colors.white : c.danger,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(enabled ? 'Notification access is on' : 'Notification access is off',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
            const SizedBox(height: 2),
            Text(
              enabled ? 'Everything else is ignored and never stored.' : 'Turn it on so the apps you choose can reach the watch.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted),
            ),
          ]),
        ),
        TextButton(onPressed: NativeBridge.instance.openListenerSettings, child: Text(enabled ? 'Manage' : 'Turn on')),
      ]),
    );
  }
}
