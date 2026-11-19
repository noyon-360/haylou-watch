import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../core/constants.dart';
import '../core/hex.dart';
import 'ble_log.dart';

typedef LinkLogger = void Function(LogDir dir, String text);

/// Transport layer: one BLE connection to the watch.
/// Knows GATT (connect, MTU, discover, notify, write) but nothing about the protocol.
class WatchLink {
  WatchLink(this.device, {required this.log});

  final BluetoothDevice device;
  final LinkLogger log;

  BluetoothCharacteristic? _cmd;
  final List<StreamSubscription<dynamic>> _subs = [];
  final StreamController<List<int>> _incoming =
      StreamController<List<int>>.broadcast();
  Future<void> _writeQueue = Future.value();

  /// Every notification frame from the watch (0x6002 and 0x6102).
  Stream<List<int>> get incoming => _incoming.stream;

  /// Connects and negotiates MTU. Returns the MTU actually agreed.
  Future<int> connect() async {
    log(LogDir.info, 'Connecting to ${device.remoteId.str}…');
    await device.connect(
      // Personal, non-commercial use (flutter_blue_plus license).
      license: License.nonprofit,
      timeout: const Duration(seconds: 15),
      mtu: watchMtu,
    );
    final mtu = device.mtuNow;
    log(LogDir.info, 'Connected, MTU $mtu');
    return mtu;
  }

  /// Finds 0x60FF / 0x6001 / 0x6002 and turns on notifications
  /// (6002 required, 6102 optional — the official app enables both).
  Future<void> setup() async {
    final services = await device.discoverServices();
    log(LogDir.info, 'Found ${services.length} services');

    final main = _find(services, watchServiceUuid);
    if (main == null) {
      throw StateError('Watch service 0x60FF not found');
    }
    _cmd = _findChar(main, commandCharUuid) ??
        (throw StateError('Command characteristic 0x6001 not found'));
    final data = _findChar(main, dataCharUuid) ??
        (throw StateError('Data characteristic 0x6002 not found'));
    await _subscribe(data, '6002');

    final secondary = _find(services, secondaryServiceUuid);
    final secNotify =
        secondary == null ? null : _findChar(secondary, secondaryNotifyCharUuid);
    if (secNotify != null) {
      try {
        await _subscribe(secNotify, '6102');
      } catch (e) {
        log(LogDir.info, 'Could not enable 6102 notifications: $e');
      }
    }
  }

  /// Writes one frame to 0x6001. Writes are queued so only one is in flight.
  Future<void> write(List<int> frame) {
    final cmd = _cmd;
    if (cmd == null) return Future.error(StateError('Not connected'));

    final next = _writeQueue.then((_) async {
      log(LogDir.tx, toHex(frame));
      // Official app uses Write Command (no response) — use it when supported.
      await cmd.write(frame,
          withoutResponse: cmd.properties.writeWithoutResponse);
    });
    _writeQueue = next.catchError((_) {}); // a failed write must not block the queue
    return next;
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _cmd = null;
    await _incoming.close();
    try {
      await device.disconnect();
    } catch (_) {
      // already disconnected
    }
  }

  Future<void> _subscribe(BluetoothCharacteristic c, String label) async {
    // Listen BEFORE enabling notifications so the first frame isn't missed.
    final sub = c.onValueReceived.listen((value) {
      log(LogDir.rx, label == '6002' ? toHex(value) : '[$label] ${toHex(value)}');
      if (!_incoming.isClosed) _incoming.add(value);
    });
    device.cancelWhenDisconnected(sub);
    _subs.add(sub);
    await c.setNotifyValue(true);
    log(LogDir.info, 'Notifications on for $label');
  }

  static BluetoothService? _find(List<BluetoothService> services, Guid uuid) {
    for (final s in services) {
      if (s.serviceUuid == uuid) return s;
    }
    return null;
  }

  static BluetoothCharacteristic? _findChar(BluetoothService s, Guid uuid) {
    for (final c in s.characteristics) {
      if (c.characteristicUuid == uuid) return c;
    }
    return null;
  }
}
