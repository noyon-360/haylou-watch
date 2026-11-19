import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_settings.dart';
import '../../platform/native_bridge.dart';
import '../../protocol/commands.dart';
import '../device/watch_controller.dart';
import 'app_types.dart';

final _listenerEnabledProvider = FutureProvider.autoDispose<bool>((ref) {
  // Re-check when the user comes back from Android's settings screen.
  final l = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(l.dispose);
  return NativeBridge.instance.isListenerEnabled();
});

final _appsProvider = FutureProvider<List<InstalledApp>>((_) => NativeBridge.instance.launchableApps());

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(_listenerEnabledProvider).value ?? false;
    final settings = ref.watch(appSettingsProvider).value ?? const AppSettings();
    final apps = ref.watch(_appsProvider);
    final store = ref.read(appSettingsProvider.notifier);
    final ready = ref.watch(watchControllerProvider.select((w) => w.isReady));

    final visible = (apps.value ?? const <InstalledApp>[])
        .where((a) => _filter.isEmpty || a.label.toLowerCase().contains(_filter) || a.package.contains(_filter))
        .toList()
      // Selected apps first.
      ..sort((a, b) {
        final sa = settings.allowedApps.contains(a.package) ? 0 : 1;
        final sb = settings.allowedApps.contains(b.package) ? 0 : 1;
        return sa != sb ? sa - sb : a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          IconButton(
            tooltip: 'Send a test alert',
            onPressed: ready
                ? () => ref.read(watchControllerProvider.notifier).sendNotification(
                    MsgType.other, 'Test', 'Hello from your phone 👋')
                : null,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverList.list(children: [
            Card(
              margin: const EdgeInsets.all(12),
              child: ListTile(
                leading: Icon(enabled ? Icons.check_circle : Icons.notifications_off,
                    color: enabled ? Colors.green : Theme.of(context).colorScheme.error),
                title: Text(enabled ? 'Notification access is on' : 'Notification access is off'),
                subtitle: const Text('Only the apps you tick below are sent to the watch. '
                    'Everything else is ignored and never stored.'),
                trailing: TextButton(
                  onPressed: NativeBridge.instance.openListenerSettings,
                  child: Text(enabled ? 'Manage' : 'Turn on'),
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.call),
              title: const Text('Incoming call alerts'),
              subtitle: const Text('Shows the caller on the watch. Read from the phone app\'s '
                  'notification, so no phone or call-log permission is needed.'),
              value: settings.callAlerts,
              onChanged: enabled ? (v) => store.edit((a) => a.copyWith(callAlerts: v)) : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search apps',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${settings.allowedApps.length} app(s) forwarded',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ]),
          if (apps.isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else
            SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (_, i) {
                final app = visible[i];
                final on = settings.allowedApps.contains(app.package);
                final known = msgTypeFor(app.package) != MsgType.other;
                return CheckboxListTile(
                  value: on,
                  enabled: enabled,
                  title: Text(app.label),
                  subtitle: Text(app.package + (known ? '' : '  · generic icon'),
                      style: Theme.of(context).textTheme.bodySmall),
                  onChanged: (v) => store.edit((a) => a.copyWith(
                        allowedApps: v == true
                            ? {...a.allowedApps, app.package}
                            : ({...a.allowedApps}..remove(app.package)),
                      )),
                );
              },
            ),
        ],
      ),
    );
  }
}
