import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_settings.dart';
import '../../protocol/commands.dart';
import '../../ui/kit.dart';
import '../device/watch_controller.dart';
import 'alert_providers.dart';
import 'app_picker_screen.dart';
import 'app_types.dart';

/// Figma "16 Alerts — overview" / "16c — no apps yet": only the forwarded
/// apps are listed here; the full list lives in [AppPickerScreen].
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _openPicker(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AppPickerScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final enabled = ref.watch(listenerEnabledProvider).value ?? false;
    final settings = ref.watch(appSettingsProvider).value ?? const AppSettings();
    final apps = ref.watch(installedAppsProvider).value;
    final store = ref.read(appSettingsProvider.notifier);
    final ready = ref.watch(watchControllerProvider.select((w) => w.isReady));

    final forwarded = settings.allowedApps.toList()
      ..sort((a, b) => appLabel(apps, a).toLowerCase().compareTo(appLabel(apps, b).toLowerCase()));

    Future<void> remove(String pkg) async {
      final label = appLabel(apps, pkg);
      await store.setAppForwarded(pkg, false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          persist: false,
          content: Text('$label won’t be sent to the watch'),
          action: SnackBarAction(label: 'Undo', onPressed: () => store.setAppForwarded(pkg, true)),
        ));
    }

    return AppPage(
      title: 'Alerts',
      subtitle: const SubtitleText('Only apps you choose reach the watch'),
      actions: [
        ChipIconButton(
          icon: Icons.send_rounded,
          tooltip: 'Send a test alert',
          onPressed: ready
              ? () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ref.read(watchControllerProvider.notifier).sendNotification(MsgType.other, 'Test', 'Hello from your phone 👋');
                  messenger.showSnackBar(const SnackBar(content: Text('Test alert sent to the watch')));
                }
              : null,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const ListenerStatusCard(),
          const SizedBox(height: 12),
          GroupCard(children: [
            SwitchRow(
              title: 'Incoming call alerts',
              subtitle: 'Shows the caller and buzzes. No contacts permission.',
              value: settings.callAlerts,
              onChanged: enabled ? (v) => store.edit((a) => a.copyWith(callAlerts: v)) : null,
            ),
          ]),
          SectionLabel(
            'Forwarded apps · ${forwarded.length}',
            trailing: forwarded.isEmpty
                ? null
                : GestureDetector(
                    onTap: () => _openPicker(context),
                    child: Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.primary)),
                  ),
          ),
          if (forwarded.isEmpty)
            _EmptyApps(onChoose: () => _openPicker(context))
          else
            GroupCard(children: [
              for (final pkg in forwarded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
                  child: Row(children: [
                    AppAvatar(label: appLabel(apps, pkg), package: pkg),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(appLabel(apps, pkg),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
                        Text(watchIconLabel(pkg), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted)),
                      ]),
                    ),
                    Tooltip(
                      message: 'Stop forwarding',
                      child: Material(
                        color: c.subtle,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => remove(pkg),
                          child: SizedBox.square(dimension: 28, child: Icon(Icons.close_rounded, size: 15, color: c.muted)),
                        ),
                      ),
                    ),
                  ]),
                ),
              InkWell(
                onTap: () => _openPicker(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(children: [
                    IconChip(icon: Icons.add_rounded, size: 38, iconSize: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Choose apps', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.primary)),
                        Text(apps == null ? 'Loading apps…' : '${apps.length} apps on this phone',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: c.muted),
                  ]),
                ),
              ),
            ]),
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: c.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Text is read only for these apps, sent to the watch, and never saved.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _EmptyApps extends StatelessWidget {
  const _EmptyApps({required this.onChoose});
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(children: [
        const IconChip(icon: Icons.notifications_none_rounded, size: 56, iconSize: 26),
        const SizedBox(height: 12),
        Text('No apps yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.text)),
        const SizedBox(height: 6),
        Text('Pick which apps can buzz your watch. Everything else stays on the phone.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w500, color: c.muted)),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: onChoose, child: const Text('Choose apps'))),
      ]),
    );
  }
}
