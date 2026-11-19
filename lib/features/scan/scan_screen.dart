import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hex.dart';
import '../../data/saved_device.dart';
import '../../ui/kit.dart';
import 'scan_providers.dart';

/// Figma "04 Scan — searching", "05 Scan — results", "06 Connect sheet".
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanning = ref.watch(isScanningProvider).value ?? false;
    final results = ref.watch(scanResultsProvider).value ?? const <ScanResult>[];
    final likely = results.where(isLikelyWatch).toList();
    final others = results.where((r) => !isLikelyWatch(r)).toList();
    final showRadar = likely.isEmpty;

    final sub = scanning
        ? (results.isEmpty ? 'Step 1 of 2 · Searching' : 'Step 1 of 2 · ${results.length} devices found')
        : (results.isEmpty ? 'Step 1 of 2 · Nothing found' : 'Step 1 of 2 · ${results.length} devices found');

    return AppPage(
      title: 'Find your watch',
      subtitle: SubtitleText(sub),
      body: Column(
        children: [
          if (scanning && !showRadar) const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 4), child: ProgressBar(height: 3)),
          Expanded(
            child: showRadar
                ? _Searching(scanning: scanning, others: others)
                : RefreshIndicator(
                    onRefresh: _startScan,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        const SectionLabel('Likely your watch'),
                        for (final r in likely) ...[
                          SurfaceCard(
                            borderColor: context.c.primary,
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                            child: Column(children: [
                              _DeviceRow(result: r, likely: true, onTap: () => _details(r)),
                              const SizedBox(height: 6),
                              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => _details(r), child: const Text('Connect'))),
                            ]),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (others.isNotEmpty) ...[
                          const SectionLabel('Other devices'),
                          GroupCard(children: [
                            for (final r in others.take(12))
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _DeviceRow(result: r, onTap: () => _details(r)),
                              ),
                          ]),
                        ],
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: scanning
                  ? OutlinedButton(onPressed: () => ref.read(scannerProvider).stop(), child: const Text('Stop searching'))
                  : FilledButton.tonal(onPressed: _startScan, child: const Text('Scan again')),
            ),
          ),
        ],
      ),
    );
  }

  void _details(ScanResult r) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _DeviceSheet(result: r),
      );
}

class _Searching extends StatelessWidget {
  const _Searching({required this.scanning, required this.others});
  final bool scanning;
  final List<ScanResult> others;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      children: [
        Center(
          child: PulseRings(
            size: 220,
            animate: scanning,
            child: IconChip(icon: Icons.watch_outlined, size: 64, iconSize: 30, background: c.primary, foreground: c.onPrimary),
          ),
        ),
        const SizedBox(height: 20),
        Text(scanning ? 'Searching nearby…' : 'No watch found yet',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text)),
        const SizedBox(height: 8),
        Text(
          scanning ? 'Keep the watch close to the phone with its screen awake.' : 'Wake the watch and tap “Scan again”. Location must be on while scanning.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.45, color: c.muted),
        ),
        const SizedBox(height: 20),
        SurfaceCard(
          color: c.soft,
          borderColor: c.soft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.info_outline_rounded, size: 18, color: c.primary),
              const SizedBox(width: 10),
              Text('One phone at a time', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.primary)),
            ]),
            const SizedBox(height: 6),
            Text('Force-stop the official Haylou app first so the watch is free to connect.',
                style: TextStyle(fontSize: 13, height: 1.45, color: c.text)),
          ]),
        ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 6),
          SectionLabel('${others.length} other devices nearby'),
          GroupCard(children: [
            for (final r in others.take(6))
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _DeviceRow(result: r, onTap: () {
                showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _DeviceSheet(result: r));
              })),
          ]),
        ],
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.result, this.likely = false, this.onTap});
  final ScanResult result;
  final bool likely;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          IconChip(
            icon: likely ? Icons.watch_outlined : Icons.bluetooth_rounded,
            size: 40,
            iconSize: 20,
            background: likely ? c.primary : c.subtle,
            foreground: likely ? c.onPrimary : c.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(displayName(result),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: likely ? FontWeight.w700 : FontWeight.w500, color: c.text)),
              Text(result.device.remoteId.str, style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: c.muted)),
            ]),
          ),
          SignalBars(result.rssi),
          const SizedBox(width: 6),
          Text('${result.rssi}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted)),
        ]),
      ),
    );
  }
}

/// Everything the device advertises + Connect.
class _DeviceSheet extends ConsumerWidget {
  const _DeviceSheet({required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final adv = result.advertisementData;
    final likely = isLikelyWatch(result);
    final services = adv.serviceUuids.map((g) => g.str.toUpperCase()).join(' · ');
    final manufacturer = adv.manufacturerData.entries
        .map((e) => '0x${e.key.toRadixString(16).padLeft(4, '0').toUpperCase()}: ${toHex(e.value)}')
        .join('\n');
    final strength = result.rssi >= -60 ? 'Strong signal · close by' : result.rssi >= -75 ? 'Good signal' : 'Weak signal · move closer';

    Widget row(String k, String v, {bool mono = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 96, child: Text(k, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.muted))),
            Expanded(
              child: SelectableText(v,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text, fontFamily: mono ? 'monospace' : null)),
            ),
          ]),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconChip(
                icon: likely ? Icons.watch_outlined : Icons.bluetooth_rounded,
                size: 48,
                iconSize: 24,
                background: likely ? c.primary : c.subtle,
                foreground: likely ? c.onPrimary : c.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(displayName(result), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
                  Text(strength,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: result.rssi >= -75 ? c.success : c.warning)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            SurfaceCard(
              color: c.canvas,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(children: [
                row('Address', result.device.remoteId.str, mono: true),
                row('Signal', '${result.rssi} dBm'),
                row('Services', services.isEmpty ? '—' : services),
                if (manufacturer.isNotEmpty) row('Maker data', manufacturer, mono: true),
                row('Pairing', 'Not needed'),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: c.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Direct Bluetooth link. Nothing is sent to the internet.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted)),
              ),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: adv.connectable
                    ? () async {
                        Navigator.of(context).pop(); // close this sheet
                        await FlutterBluePlus.stopScan();
                        // Saving switches HomeRouter to the Watch tab, which connects.
                        await ref.read(savedDeviceProvider.notifier).save(
                              SavedDevice(id: result.device.remoteId.str, name: displayName(result)),
                            );
                      }
                    : null,
                child: Text(adv.connectable ? 'Connect to this watch' : 'Not connectable'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
