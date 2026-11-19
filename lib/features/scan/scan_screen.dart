import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hex.dart';
import '../../data/saved_device.dart';
import 'scan_providers.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  @override
  void initState() {
    super.initState();
    // Start scanning as soon as the screen is shown.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  Future<void> _startScan() async {
    try {
      await ref.read(scannerProvider).start();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanning = ref.watch(isScanningProvider).value ?? false;
    final results = ref.watch(scanResultsProvider).value ?? const <ScanResult>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find your watch'),
        bottom: scanning
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: results.isEmpty
          ? _EmptyState(scanning: scanning)
          : RefreshIndicator(
              onRefresh: _startScan,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _DeviceTile(result: results[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: scanning ? () => ref.read(scannerProvider).stop() : _startScan,
        icon: Icon(scanning ? Icons.stop : Icons.search),
        label: Text(scanning ? 'Stop' : 'Scan'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scanning});
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          scanning
              ? 'Searching for devices…'
              : 'No devices found.\n\n'
                  'Make sure the official Haylou app is force-stopped '
                  '(the watch can only talk to one phone at a time), then tap Scan.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final watch = isLikelyWatch(result);
    final primary = Theme.of(context).colorScheme.primary;

    return ListTile(
      leading: Icon(watch ? Icons.watch : Icons.bluetooth,
          color: watch ? primary : null),
      title: Text(
        displayName(result),
        style: watch ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: Text(result.device.remoteId.str),
      trailing: Text('${result.rssi} dBm'),
      onTap: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _DeviceDetails(result: result),
      ),
    );
  }
}

/// Everything the device advertises. Use this to record the watch's real name/UUIDs.
class _DeviceDetails extends ConsumerWidget {
  const _DeviceDetails({required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adv = result.advertisementData;
    final services = adv.serviceUuids.map((g) => g.str.toUpperCase()).join(', ');
    final manufacturer = adv.manufacturerData.entries
        .map((e) =>
            '0x${e.key.toRadixString(16).padLeft(4, '0').toUpperCase()}: ${toHex(e.value)}')
        .join('\n');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName(result),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _Row('Address', result.device.remoteId.str),
            _Row('Adv name', adv.advName.isEmpty ? '-' : adv.advName),
            _Row('RSSI', '${result.rssi} dBm'),
            _Row('Connectable', adv.connectable ? 'yes' : 'no'),
            _Row('TX power', adv.txPowerLevel?.toString() ?? '-'),
            _Row('Services', services.isEmpty ? '-' : services),
            _Row('Manufacturer', manufacturer.isEmpty ? '-' : manufacturer),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: result.advertisementData.connectable
                    ? () async {
                        Navigator.of(context).pop(); // close this sheet
                        await FlutterBluePlus.stopScan();
                        // Saving switches HomeRouter to DeviceScreen, which connects.
                        await ref.read(savedDeviceProvider.notifier).save(
                              SavedDevice(
                                id: result.device.remoteId.str,
                                name: displayName(result),
                              ),
                            );
                      }
                    : null,
                child: const Text('Connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
