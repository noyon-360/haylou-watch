import 'dart:async';

import '../ble/watch_link.dart';
import 'commands.dart';

/// Protocol layer on top of [WatchLink]: request/response by opcode echo,
/// handshake replay, typed commands.
class WatchSession {
  WatchSession(this.link);

  final WatchLink link;

  static const _defaultTimeout = Duration(seconds: 3);

  /// Sends [frame] and waits for the first reply whose first byte equals the opcode.
  Future<List<int>> request(List<int> frame,
      {Duration timeout = _defaultTimeout}) async {
    final opcode = frame.first;
    final completer = Completer<List<int>>();
    // Subscribe before writing so a fast reply isn't missed.
    final sub = link.incoming.listen((reply) {
      if (reply.isNotEmpty && reply.first == opcode && !completer.isCompleted) {
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
}
