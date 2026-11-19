import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';

/// True if the advertised name matches a hint OR the watch's 0x60FF service is advertised.
bool isLikelyWatch(ScanResult r) {
  final name = r.advertisementData.advName.toLowerCase();
  if (watchNameHints.any(name.contains)) return true;
  return r.advertisementData.serviceUuids.contains(watchServiceUuid);
}

String displayName(ScanResult r) {
  final adv = r.advertisementData.advName;
  if (adv.isNotEmpty) return adv;
  final platform = r.device.platformName;
  return platform.isNotEmpty ? platform : '(no name)';
}

/// Live scan results: likely watches first, then strongest signal.
final scanResultsProvider = StreamProvider<List<ScanResult>>((ref) {
  return FlutterBluePlus.scanResults.map((results) {
    return [...results]..sort((a, b) {
        final byWatch =
            (isLikelyWatch(b) ? 1 : 0) - (isLikelyWatch(a) ? 1 : 0);
        return byWatch != 0 ? byWatch : b.rssi.compareTo(a.rssi);
      });
  });
});

final isScanningProvider =
    StreamProvider<bool>((ref) => FlutterBluePlus.isScanning);

final scannerProvider = Provider<Scanner>((ref) => const Scanner());

class Scanner {
  const Scanner();

  static const timeout = Duration(seconds: 10);

  Future<void> start() async {
    if (FlutterBluePlus.isScanningNow) return;
    // No service filter yet: we don't know what the watch advertises.
    await FlutterBluePlus.startScan(timeout: timeout);
  }

  Future<void> stop() => FlutterBluePlus.stopScan();
}
