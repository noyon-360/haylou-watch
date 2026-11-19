import 'dart:async';
import 'dart:math';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ble/ble_log.dart';
import '../../ble/watch_link.dart';
import '../../core/hex.dart';
import '../../data/health_store.dart';
import '../../platform/native_bridge.dart';
import '../../protocol/commands.dart';
import '../../protocol/history.dart';
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
    this.liveHeart,
    this.liveHeartAt,
    this.syncing = false,
    this.lastSync,
    this.findingPhone = false,
    this.infoLoaded = false,
    this.syncStep,
    this.syncNotes = const [null, null, null],
    this.lastSyncSummary,
    this.retryAt,
    this.attempt = 0,
    this.lastSeen,
  });

  /// Battery/serial/time have been read on this connection.
  final bool infoLoaded;

  /// While syncing: 0 = steps, 1 = heart rate, 2 = sleep.
  final int? syncStep;

  /// Per-step result text shown in the sync card (steps, heart, sleep).
  final List<String?> syncNotes;

  /// e.g. "Synced 7 days · steps, heart rate & sleep" (for the toast).
  final String? lastSyncSummary;

  /// Next automatic reconnect attempt, and how many have been made.
  final DateTime? retryAt;
  final int attempt;

  /// When the link last dropped.
  final DateTime? lastSeen;

  final LinkStatus status;
  final String? deviceId;
  final int? mtu;
  final int? battery;
  final String? serial;

  /// Error or info for the user (e.g. "Retrying in 4 s").
  final String? message;

  /// Last bpm pushed by the watch while it measures.
  final int? liveHeart;
  final DateTime? liveHeartAt;

  final bool syncing;
  final DateTime? lastSync;
  final bool findingPhone;

  bool get isReady => status == LinkStatus.ready;

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
    int? liveHeart,
    DateTime? liveHeartAt,
    bool? syncing,
    DateTime? lastSync,
    bool? findingPhone,
    bool? infoLoaded,
    int? syncStep,
    bool clearSyncStep = false,
    List<String?>? syncNotes,
    String? lastSyncSummary,
    DateTime? retryAt,
    bool clearRetry = false,
    int? attempt,
    DateTime? lastSeen,
  }) {
    return WatchState(
      infoLoaded: infoLoaded ?? this.infoLoaded,
      syncStep: clearSyncStep ? null : (syncStep ?? this.syncStep),
      syncNotes: syncNotes ?? this.syncNotes,
      lastSyncSummary: lastSyncSummary ?? this.lastSyncSummary,
      retryAt: clearRetry ? null : (retryAt ?? this.retryAt),
      attempt: attempt ?? this.attempt,
      lastSeen: lastSeen ?? this.lastSeen,
      status: status ?? this.status,
      deviceId: deviceId ?? this.deviceId,
      mtu: mtu ?? this.mtu,
      battery: battery ?? this.battery,
      serial: serial ?? this.serial,
      message: clearMessage ? null : (message ?? this.message),
      liveHeart: liveHeart ?? this.liveHeart,
      liveHeartAt: liveHeartAt ?? this.liveHeartAt,
      syncing: syncing ?? this.syncing,
      lastSync: lastSync ?? this.lastSync,
      findingPhone: findingPhone ?? this.findingPhone,
    );
  }
}

final watchControllerProvider =
    NotifierProvider<WatchController, WatchState>(WatchController.new);

/// Owns the connection lifecycle: connect -> discover -> handshake -> ready,
/// auto-reconnect with backoff, and every command sent to the watch.
class WatchController extends Notifier<WatchState> {
  WatchLink? _link;
  WatchSession? _session;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _pushSub;
  Timer? _retryTimer;
  Timer? _periodic;
  int _attempt = 0;
  bool _userDisconnected = false;

  /// Serialises all watch traffic so multi-frame transfers never interleave.
  Future<void> _lock = Future.value();

  BleLog get _log => ref.read(bleLogProvider.notifier);

  @override
  WatchState build() {
    ref.onDispose(() {
      _retryTimer?.cancel();
      _periodic?.cancel();
      _closeLink();
    });
    return const WatchState();
  }

  Future<void> connect(String deviceId) async {
    if (state.isBusy || state.isReady) return;
    _userDisconnected = false;
    _retryTimer?.cancel();

    await FlutterBluePlus.stopScan(); // scanning slows down connecting
    await _closeLink();

    state = WatchState(
      status: LinkStatus.connecting,
      deviceId: deviceId,
      battery: state.battery,
      serial: state.serial,
      lastSync: state.lastSync,
      lastSyncSummary: state.lastSyncSummary,
      attempt: state.attempt,
      lastSeen: state.lastSeen,
    );
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
      _pushSub = link.incoming.listen(_onPush);
      _log.add(LogDir.info, 'Handshake OK');

      _attempt = 0;
      state = state.copyWith(status: LinkStatus.ready, clearMessage: true, clearRetry: true, attempt: 0);
      await _onConnected();
    } catch (e) {
      _log.add(LogDir.info, 'Connect failed: $e');
      await _closeLink();
      if (_userDisconnected) return;
      state = state.copyWith(status: LinkStatus.error, message: '$e');
      _scheduleReconnect();
    }
  }

  Future<void> _onConnected() async {
    try {
      await _run((s) => s.setTime(DateTime.now()));
    } catch (e) {
      _log.add(LogDir.info, 'Set time failed: $e');
    }
    await refreshInfo();
    if (state.isReady) state = state.copyWith(infoLoaded: true);
    await syncHealth();
    _periodic?.cancel();
    _periodic = Timer.periodic(const Duration(minutes: 15), (_) async {
      await refreshInfo();
      await syncHealth();
    });
  }

  /// Runs [op] with the session, one at a time. Returns null when not connected.
  Future<T?> _run<T>(Future<T> Function(WatchSession s) op) {
    final result = Completer<T?>();
    _lock = _lock.then((_) async {
      final s = _session;
      if (s == null || !state.isReady) {
        result.complete(null);
        return;
      }
      try {
        result.complete(await op(s));
      } catch (e, st) {
        result.completeError(e, st);
      }
    });
    return result.future;
  }

  /// Reads battery, serial and the watch's own switch states.
  Future<void> refreshInfo() async {
    try {
      final battery = await _run((s) => s.battery());
      if (battery != null) state = state.copyWith(battery: battery);
    } catch (e) {
      _log.add(LogDir.info, 'Battery read failed: $e');
    }
    try {
      final serial = await _run((s) => s.serial());
      if (serial != null) state = state.copyWith(serial: serial);
    } catch (e) {
      _log.add(LogDir.info, 'Serial read failed: $e');
    }
    // Note: the 0C 02 switch-state reply is logged but NOT applied to settings:
    // on this watch it sometimes reads all-zero (seen live 2026-11-19).
    try {
      await _run((s) => s.quickSwitches());
    } catch (_) {}
  }

  /// Pulls the last 7 days of steps, heart rate and sleep into local storage.
  Future<void> syncHealth() async {
    if (!state.isReady || state.syncing) return;
    state = state.copyWith(syncing: true, syncStep: 0, syncNotes: const [null, null, null]);
    final now = DateTime.now();
    final since = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    // Drop records outside the window (the watch reports e.g. 2021-01-01
    // leftovers from before its clock was set).
    final from = dayKey(since), to = dayKey(now);
    bool inRange(String d) => d.compareTo(from) >= 0 && d.compareTo(to) <= 0;
    void note(int i, String text, {int? next}) {
      final notes = [...state.syncNotes]..[i] = text;
      state = state.copyWith(syncNotes: notes, syncStep: next, clearSyncStep: next == null);
    }

    try {
      final steps = await _run((s) => s.stepHistory(since)) ?? const <StepRecord>[];
      final stepDays = steps.where((r) => inRange(r.day)).map((r) => r.day).toSet().length;
      note(0, '$stepDays days · ${steps.where((r) => inRange(r.day)).length} hourly records', next: 1);
      final heart = await _run((s) => s.heartHistory(since)) ?? const <String, List<int>>{};
      final readings = heart.entries.where((e) => inRange(e.key)).fold(0, (a, e) => a + e.value.where((v) => v > 0).length);
      note(1, '${heart.keys.where(inRange).length} days · $readings readings', next: 2);
      final sleep = await _run((s) => s.sleepHistory(since)) ?? const <String, List<SleepSegment>>{};
      note(2, '${sleep.keys.where(inRange).length} nights');
      await ref.read(healthStoreProvider.notifier).merge(
            steps: steps.where((r) => inRange(r.day)).toList(),
            heart: {for (final e in heart.entries) if (inRange(e.key)) e.key: e.value},
            sleep: {for (final e in sleep.entries) if (inRange(e.key)) e.key: e.value},
          );
      _log.add(LogDir.info,
          'Synced ${steps.length} step hours, ${heart.length} HR days, ${sleep.length} nights');
      final days = {...steps.map((r) => r.day), ...heart.keys, ...sleep.keys}.where(inRange).length;
      state = state.copyWith(
        syncing: false,
        clearSyncStep: true,
        lastSync: DateTime.now(),
        lastSyncSummary: 'Synced $days ${days == 1 ? 'day' : 'days'} · steps, heart rate & sleep',
      );
    } catch (e) {
      _log.add(LogDir.info, 'Health sync failed: $e');
      state = state.copyWith(syncing: false, clearSyncStep: true, message: 'Sync failed: $e');
    }
  }

  // ---- commands used by the UI --------------------------------------------

  Future<void> findWatch() => _run((s) => s.findWatch());

  Future<void> applyFormat({required bool metric, required bool use24h}) =>
      _run((s) => s.setFormat(metric: metric, use24h: use24h));

  Future<void> applyParams(DeviceParams p) => _run((s) => s.setParams(p));

  Future<void> applyDnd(DndSettings d) => _run((s) => s.setDnd(d));

  Future<void> applySedentary(SedentarySettings d) => _run((s) => s.setSedentary(d));

  Future<void> applyHeartMode(bool auto) => _run((s) => s.setHeartMode(auto: auto));

  Future<void> sendNotification(int type, String title, String body) =>
      _run((s) => s.writeAll(messageFrames(type, title, body)));

  Future<void> sendCall(String caller) => _run((s) => s.writeAll(callFrames(caller)));

  Future<void> endCall() => _run((s) async {
        await s.callBuzz(stop: true);
        await s.link.write(Commands.callEnd);
      });

  /// One vibration burst while a call is ringing (repeated by AppRuntime).
  Future<void> buzzForCall() => _run((s) => s.callBuzz());

  Future<void> stopFindingPhone() async {
    state = state.copyWith(findingPhone: false);
    await NativeBridge.instance.ring(false);
  }

  /// Debug console: send arbitrary hex to 0x6001. Factory reset is refused.
  Future<void> sendRaw(String hex) async {
    final frame = fromHex(hex);
    if (blockedOpcodes.contains(frame.first)) {
      throw StateError('Opcode ${toHex([frame.first])} is blocked (factory reset)');
    }
    final link = _link;
    if (link == null || !state.isReady) throw StateError('Not connected');
    await link.write(frame);
  }

  Future<void> disconnect() async {
    _userDisconnected = true;
    _retryTimer?.cancel();
    await _closeLink();
    state = state.copyWith(status: LinkStatus.disconnected, message: 'Disconnected');
    _log.add(LogDir.info, 'Disconnected by user');
  }

  /// "Forget this watch": disconnect and drop all per-watch state, so pairing
  /// (even the same watch) again starts a fresh connection.
  Future<void> forget() async {
    await disconnect();
    _attempt = 0;
    state = const WatchState();
  }

  // ---- unsolicited frames from the watch ----------------------------------

  void _onPush(List<int> f) {
    final bpm = decodeLiveHeart(f);
    if (bpm != null) {
      state = state.copyWith(liveHeart: bpm, liveHeartAt: DateTime.now());
      return;
    }
    final find = decodeFindPhone(f);
    if (find != null) {
      final on = switch (find) {
        FindPhone.start => true,
        FindPhone.stop => false,
        FindPhone.toggle => !state.findingPhone,
      };
      state = state.copyWith(findingPhone: on);
      NativeBridge.instance.ring(on);
    }
  }

  void _watchForDisconnect(BluetoothDevice device) {
    _connSub?.cancel();
    _connSub = device.connectionState.listen((s) {
      if (s != BluetoothConnectionState.disconnected) return;
      if (state.status == LinkStatus.disconnected) return;
      _log.add(LogDir.info,
          'Connection lost (reason: ${device.disconnectReason?.description ?? 'unknown'})');
      _session = null;
      _periodic?.cancel();
      state = state.copyWith(status: LinkStatus.disconnected, lastSeen: DateTime.now(), infoLoaded: false, syncing: false, clearSyncStep: true);
      _scheduleReconnect();
    });
  }

  /// Called by the runtime when Bluetooth comes back on.
  void reconnectNow() {
    final id = state.deviceId;
    if (id == null || _userDisconnected || state.isBusy || state.isReady) return;
    _attempt = 0;
    connect(id);
  }

  void _scheduleReconnect() {
    final id = state.deviceId;
    if (_userDisconnected || id == null) return;
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) return;

    final seconds = min(30, 2 << _attempt); // 2, 4, 8, 16, 30, 30…
    _attempt++;
    final note = 'Retrying in $seconds s';
    _log.add(LogDir.info, note);
    state = state.copyWith(
      message: note,
      retryAt: DateTime.now().add(Duration(seconds: seconds)),
      attempt: _attempt,
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), () => connect(id));
  }

  Future<void> _closeLink() async {
    _periodic?.cancel();
    await _pushSub?.cancel();
    _pushSub = null;
    await _connSub?.cancel();
    _connSub = null;
    _session = null;
    final link = _link;
    _link = null;
    await link?.dispose();
  }
}
