import 'dart:async';
import 'dart:math';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ble/ble_log.dart';
import '../../ble/watch_link.dart';
import '../../core/hex.dart';
import '../../protocol/watch_session.dart';

enum LinkStatus { disconnected, connecting, discovering, handshaking, ready, error }

class WatchState {
  const WatchState({
    this.status = LinkStatus.disconnected,
    this.deviceId,
    this.mtu,
    this.battery,
    this.serial,
    this.message,
  });

  final LinkStatus status;
  final String? deviceId;
  final int? mtu;
  final int? battery;
  final String? serial;

  /// Error or info for the user (e.g. "Retrying in 4 s").
  final String? message;

  bool get isBusy =>
      status == LinkStatus.connecting ||
      status == LinkStatus.discovering ||
      status == LinkStatus.handshaking;

  WatchState copyWith({
    LinkStatus? status,
    String? deviceId,
    int? mtu,
    int? battery,
    String? serial,
    String? message,
    bool clearMessage = false,
  }) {
    return WatchState(
      status: status ?? this.status,
      deviceId: deviceId ?? this.deviceId,
      mtu: mtu ?? this.mtu,
      battery: battery ?? this.battery,
      serial: serial ?? this.serial,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

final watchControllerProvider =
    NotifierProvider<WatchController, WatchState>(WatchController.new);

/// Owns the connection lifecycle: connect -> discover -> handshake -> ready,
/// plus auto-reconnect with backoff.
class WatchController extends Notifier<WatchState> {
  WatchLink? _link;
  WatchSession? _session;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _userDisconnected = false;

  BleLog get _log => ref.read(bleLogProvider.notifier);

  @override
  WatchState build() {
    ref.onDispose(() {
      _retryTimer?.cancel();
      _closeLink();
    });
    return const WatchState();
  }

  Future<void> connect(String deviceId) async {
    if (state.isBusy) return;
    _userDisconnected = false;
    _retryTimer?.cancel();

    await FlutterBluePlus.stopScan(); // scanning slows down connecting
    await _closeLink();

    state = WatchState(status: LinkStatus.connecting, deviceId: deviceId);
    final link = WatchLink(BluetoothDevice.fromId(deviceId), log: _log.add);
    _link = link;

    try {
      final mtu = await link.connect();
      _watchForDisconnect(link.device);

      state = state.copyWith(status: LinkStatus.discovering, mtu: mtu);
      await link.setup();

      state = state.copyWith(status: LinkStatus.handshaking);
      final session = WatchSession(link);
      await session.handshake();
      _session = session;
      _log.add(LogDir.info, 'Handshake OK');

      _attempt = 0;
      state = state.copyWith(status: LinkStatus.ready, clearMessage: true);
      await refreshInfo();
    } catch (e) {
      _log.add(LogDir.info, 'Connect failed: $e');
      await _closeLink();
      state = state.copyWith(status: LinkStatus.error, message: '$e');
      _scheduleReconnect();
    }
  }

  /// Reads battery + serial. Safe to call any time while ready.
  Future<void> refreshInfo() async {
    final session = _session;
    if (session == null || state.status != LinkStatus.ready) return;
    try {
      final battery = await session.battery();
      state = state.copyWith(battery: battery);
    } catch (e) {
      _log.add(LogDir.info, 'Battery read failed: $e');
    }
    try {
      final serial = await session.serial();
      state = state.copyWith(serial: serial);
    } catch (e) {
      _log.add(LogDir.info, 'Serial read failed: $e');
    }
  }

  /// Debug console: send arbitrary hex to 0x6001.
  Future<void> sendRaw(String hex) async {
    final link = _link;
    if (link == null || state.status != LinkStatus.ready) {
      throw StateError('Not connected');
    }
    await link.write(fromHex(hex));
  }

  Future<void> disconnect() async {
    _userDisconnected = true;
    _retryTimer?.cancel();
    await _closeLink();
    state = state.copyWith(
        status: LinkStatus.disconnected, message: 'Disconnected');
    _log.add(LogDir.info, 'Disconnected by user');
  }

  void _watchForDisconnect(BluetoothDevice device) {
    _connSub?.cancel();
    _connSub = device.connectionState.listen((s) {
      if (s != BluetoothConnectionState.disconnected) return;
      if (state.status == LinkStatus.disconnected) return;
      _log.add(LogDir.info,
          'Connection lost (reason: ${device.disconnectReason?.description ?? 'unknown'})');
      _session = null;
      state = state.copyWith(status: LinkStatus.disconnected);
      _scheduleReconnect();
    });
  }

  void _scheduleReconnect() {
    final id = state.deviceId;
    if (_userDisconnected || id == null) return;
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) return;

    final seconds = min(30, 2 << _attempt); // 2, 4, 8, 16, 30, 30…
    _attempt++;
    final note = 'Retrying in $seconds s';
    _log.add(LogDir.info, note);
    state = state.copyWith(message: note);
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), () => connect(id));
  }

  Future<void> _closeLink() async {
    await _connSub?.cancel();
    _connSub = null;
    _session = null;
    final link = _link;
    _link = null;
    await link?.dispose();
  }
}
