import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/saved_device.dart';
import '../debug/console_screen.dart';
import 'watch_controller.dart';

class DeviceScreen extends ConsumerWidget {
  const DeviceScreen({super.key, required this.device});
  final SavedDevice device;

  Future<void> _forget(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Forget this watch?'),
        content: const Text('The app disconnects and you can pair again from the scan screen. '
            'Health data stored on this phone is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Forget')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(watchControllerProvider.notifier).disconnect();
    await ref.read(savedDeviceProvider.notifier).clear();
  }

  Future<void> _guard(BuildContext context, Future<void> Function() op, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await op();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ref.watch(watchControllerProvider);
    final controller = ref.read(watchControllerProvider.notifier);
    final ready = watch.isReady;

    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'forget') _forget(context, ref);
              if (v == 'console') {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsoleScreen()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'console', child: Text('Debug console')),
              PopupMenuItem(value: 'forget', child: Text('Forget this watch')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (watch.findingPhone)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.phonelink_ring),
                title: const Text('Your watch is looking for this phone'),
                trailing: FilledButton(onPressed: controller.stopFindingPhone, child: const Text('Stop')),
              ),
            ),
          _StatusCard(
            state: watch,
            deviceId: device.id,
            onConnect: () => controller.connect(device.id),
            onDisconnect: controller.disconnect,
          ),
          _InfoCard(state: watch, onRefresh: ready ? controller.refreshInfo : null),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: ready
                        ? () => _guard(context, controller.findWatch, 'Watch is vibrating')
                        : null,
                    icon: const Icon(Icons.vibration),
                    label: const Text('Find watch'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: ready && !watch.syncing
                        ? () => _guard(context, controller.syncHealth, 'Health data synced')
                        : null,
                    icon: watch.syncing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync),
                    label: const Text('Sync now'),
                  ),
                ),
              ],
            ),
          ),
          if (watch.liveHeart != null)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.favorite, color: Colors.red),
                title: Text('${watch.liveHeart} bpm'),
                subtitle: Text('Live from the watch · ${_hm(watch.liveHeartAt!)}'),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(
              'Everything stays on this phone. The app talks only to your watch over Bluetooth: '
              'no account, no internet, no analytics.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.state,
    required this.deviceId,
    required this.onConnect,
    required this.onDisconnect,
  });

  final WatchState state;
  final String deviceId;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (state.status) {
      LinkStatus.ready => ('Connected', Icons.bluetooth_connected, Colors.green),
      LinkStatus.connecting => ('Connecting…', Icons.bluetooth_searching, scheme.primary),
      LinkStatus.discovering => ('Discovering services…', Icons.bluetooth_searching, scheme.primary),
      LinkStatus.handshaking => ('Handshake…', Icons.bluetooth_searching, scheme.primary),
      LinkStatus.error => ('Connection failed', Icons.error_outline, scheme.error),
      LinkStatus.disconnected => ('Disconnected', Icons.bluetooth_disabled, scheme.outline),
    };

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  Text(deviceId, style: Theme.of(context).textTheme.bodySmall),
                  if (state.message != null)
                    Text(state.message!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (state.isBusy)
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            else if (state.isReady)
              TextButton(onPressed: onDisconnect, child: const Text('Disconnect'))
            else
              FilledButton(onPressed: onConnect, child: const Text('Connect')),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.state, required this.onRefresh});
  final WatchState state;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final b = state.battery;
    final icon = b == null
        ? Icons.battery_unknown
        : b > 80
            ? Icons.battery_full
            : b > 50
                ? Icons.battery_5_bar
                : b > 20
                    ? Icons.battery_3_bar
                    : Icons.battery_alert;
    final sync = state.lastSync == null ? 'never' : _hm(state.lastSync!);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(b == null ? '--' : '$b%', style: text.headlineSmall),
            const SizedBox(width: 24),
            Expanded(
              child: Text('Serial: ${state.serial ?? '--'}\nLast sync: $sync', style: text.bodySmall),
            ),
            IconButton(tooltip: 'Refresh', onPressed: onRefresh, icon: const Icon(Icons.refresh)),
          ],
        ),
      ),
    );
  }
}
