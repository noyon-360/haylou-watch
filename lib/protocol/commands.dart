/// Pure-Dart protocol frames for the UTE/Youcy watch protocol.
/// No BLE here, so everything is unit-testable (see test/protocol/).
///
/// Frame format: raw `[opcode][payload…]`, no length/CRC.
/// The watch replies on 0x6002 with the same first byte (opcode echo).
library;

import 'dart:convert';

abstract final class Op {
  static const int serial = 0x02;
  static const int battery = 0x03;
  static const int setTime = 0x04;
  static const int handshake = 0x20;
  static const int config = 0x25;
}

abstract final class Commands {
  /// Sent first on every connect (captured; assumed static — see CLAUDE.md §10).
  static const List<int> handshake = [0x20, 0x02, 0x05, 0x61, 0x97, 0x4A];

  /// Sent right after the handshake by the official app.
  static const List<int> config = [0x25, 0xAB, 0x02];

  static const List<int> battery = [Op.battery];
  static const List<int> serial = [Op.serial];
}

/// `03 1E` -> 30. Returns null if the frame isn't a battery reply.
int? decodeBattery(List<int> frame) {
  if (frame.length < 2 || frame[0] != Op.battery) return null;
  final percent = frame[1];
  return percent <= 100 ? percent : null;
}

/// `02 52 48 32 …` -> "RH2…". Returns null if the frame isn't a serial reply.
String? decodeSerial(List<int> frame) {
  if (frame.length < 2 || frame[0] != Op.serial) return null;
  final text = ascii.decode(frame.sublist(1), allowInvalid: true);
  return text.replaceAll('\u0000', '').trim();
}

/// Expected handshake reply: `20 04 01`.
bool isHandshakeOk(List<int> frame) =>
    frame.length >= 3 && frame[0] == Op.handshake && frame[1] == 0x04 && frame[2] == 0x01;
