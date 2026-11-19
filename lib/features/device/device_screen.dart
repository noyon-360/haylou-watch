import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ble/ble_log.dart';
import '../../data/saved_device.dart';
import 'watch_controller.dart';

class DeviceScreen extends ConsumerStatefulWidget {
  const DeviceScreen({super.key, required this.device});
  final SavedDevice device;

  @override
  ConsumerState<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends ConsumerState<DeviceScreen> {
  final _hexController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-connect to the saved watch (no scan needed, works with Location off).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(watchControllerProvider);
      if (s.status != LinkStatus.ready && !s.isBusy) {
        ref.read(watchControllerProvider.notifier).connect(widget.device.id);
      }
    });
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Future<void> _forget() async {
    await ref.read(watchControllerProvider.notifier).disconnect();
    await ref.read(savedDeviceProvider.notifier).clear();
  }

  Future<void> _send() async {
    try {
      await ref
          .read(watchControllerProvider.notifier)
          .sendRaw(_hexController.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Send failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final watch = ref.watch(watchControllerProvider);
    final controller = ref.read(watchControllerProvider.notifier);
    final ready = watch.status == LinkStatus.ready;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'forget') _forget();
              if (v == 'clear') ref.read(bleLogProvider.notifier).clear();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear log')),
              PopupMenuItem(value: 'forget', child: Text('Forget this watch')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _StatusCard(
            state: watch,
            deviceId: widget.device.id,
            onConnect: () => controller.connect(widget.device.id),
            onDisconnect: controller.disconnect,
          ),
          _InfoCard(state: watch, onRefresh: ready ? controller.refreshInfo : null),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Raw log  (→ sent to 6001,  ← received on 6002)'),
            ),
          ),
          const Expanded(child: _LogView()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      enabled: ready,
                      style: const TextStyle(fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: 'hex, e.g. 03',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: ready ? _send : null,
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else if (state.status == LinkStatus.ready)
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.battery_std),
            const SizedBox(width: 8),
            Text(state.battery == null ? '--' : '${state.battery}%',
                style: text.headlineSmall),
            const SizedBox(width: 24),
            Expanded(
              child: Text('Serial: ${state.serial ?? '--'}\nMTU: ${state.mtu ?? '--'}',
                  style: text.bodySmall),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogView extends ConsumerWidget {
  const _LogView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(bleLogProvider);
    final scheme = Theme.of(context).colorScheme;

    if (entries.isEmpty) {
      return const Center(child: Text('No traffic yet'));
    }
    return ListView.builder(
      reverse: true, // newest at the bottom, auto-scrolls
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[entries.length - 1 - i];
        final t = e.time;
        final time =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
        final (arrow, color) = switch (e.dir) {
          LogDir.tx => ('→', scheme.primary),
          LogDir.rx => ('←', Colors.green),
          LogDir.info => ('•', scheme.outline),
        };
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: SelectableText(
            '$time $arrow ${e.text}',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: color),
          ),
        );
      },
    );
  }
}
