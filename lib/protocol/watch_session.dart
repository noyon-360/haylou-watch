import 'dart:async';

import '../ble/watch_link.dart';
import 'commands.dart';
import 'history.dart';

/// Protocol layer on top of [WatchLink]: request/response by opcode echo,
/// handshake replay, typed commands, history transfers.
class WatchSession {
  WatchSession(this.link);

  final WatchLink link;

  static const _defaultTimeout = Duration(seconds: 3);

  /// Sends [frame] and waits for the first reply whose first byte equals the
  /// opcode (and that passes [match], if given).
  Future<List<int>> request(List<int> frame,
      {Duration timeout = _defaultTimeout, bool Function(List<int>)? match}) async {
    final opcode = frame.first;
    final completer = Completer<List<int>>();
    // Subscribe before writing so a fast reply isn't missed.
    final sub = link.incoming.listen((reply) {
      if (reply.isNotEmpty &&
          reply.first == opcode &&
          (match == null || match(reply)) &&
          !completer.isCompleted) {
        completer.complete(reply);
      }
    });
    try {
      await link.write(frame);
      return await completer.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
            'No reply to opcode 0x${opcode.toRadixString(16).padLeft(2, '0')}'),
      );
    } finally {
      await sub.cancel();
    }
  }

  /// Sends [frame] and feeds every incoming frame to [onFrame] until it
  /// returns true (end marker) or nothing arrives for [idle].
  Future<void> collect(List<int> frame, bool Function(List<int>) onFrame,
      {Duration idle = const Duration(seconds: 5)}) async {
    final done = Completer<void>();
    Timer? timer;
    void arm() {
      timer?.cancel();
      timer = Timer(idle, () {
        if (!done.isCompleted) done.complete(); // keep what we have
      });
    }

    final sub = link.incoming.listen((f) {
      if (done.isCompleted) return;
      arm();
      if (onFrame(f)) done.complete();
    });
    try {
      arm();
      await link.write(frame);
      await done.future;
    } finally {
      timer?.cancel();
      await sub.cancel();
    }
  }

  /// Writes several frames in order (multi-packet notifications).
  Future<void> writeAll(List<List<int>> frames) async {
    for (final f in frames) {
      await link.write(f);
    }
  }

  /// Replays the captured connect sequence: handshake (20…) then config (25 AB 02).
  Future<void> handshake() async {
    final reply = await request(Commands.handshake);
    if (!isHandshakeOk(reply)) {
      throw StateError('Unexpected handshake reply: $reply');
    }
    await request(Commands.config);
  }

  Future<int> battery() async {
    final reply = await request(Commands.battery);
    return decodeBattery(reply) ??
        (throw FormatException('Bad battery reply', reply));
  }

  Future<String> serial() async {
    final reply = await request(Commands.serial);
    return decodeSerial(reply) ??
        (throw FormatException('Bad serial reply', reply));
  }

  Future<void> setTime(DateTime now) => request(Commands.setTime(now));

  Future<QuickSwitches?> quickSwitches() async =>
      decodeQuickSwitches(await request(Commands.quickSwitch));

  Future<void> findWatch({bool stop = false}) =>
      request(stop ? Commands.stopFindWatch : Commands.findWatch);

  Future<void> setFormat({required bool metric, required bool use24h}) =>
      request(Commands.format(metric: metric, use24h: use24h));

  Future<void> setParams(DeviceParams p) => request(Commands.params(p));

  Future<void> setDnd(DndSettings s) => request(Commands.dnd(s));

  Future<void> setSedentary(SedentarySettings s) =>
      request(Commands.sedentary(s));

  Future<void> setHeartMode({required bool auto}) => request(
        Commands.heartMode(auto: auto),
        // Live-HR status frames (18 03 / 18 04) also start with 0x18.
        match: (r) => r.length == 2,
      );

  Future<List<StepRecord>> stepHistory(DateTime since) async {
    final c = StepHistoryCollector();
    await collect(Commands.stepHistory(since), c.add);
    return c.records;
  }

  Future<Map<String, List<int>>> heartHistory(DateTime since) async {
    final c = HeartHistoryCollector();
    await collect(Commands.heartHistory(since), c.add);
    return c.days;
  }

  Future<Map<String, List<SleepSegment>>> sleepHistory(DateTime since) async {
    final c = SleepHistoryCollector();
    await collect(Commands.sleepHistory(since), c.add);
    return c.nights;
  }
}
