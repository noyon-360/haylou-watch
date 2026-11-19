import 'package:flutter_test/flutter_test.dart';
import 'package:watch/core/hex.dart';
import 'package:watch/protocol/commands.dart';

/// Fixtures are real frames from the HCI capture (CLAUDE.md §2).
void main() {
  group('frames match the capture', () {
    test('handshake bytes', () {
      expect(toHex(Commands.handshake), '20 02 05 61 97 4A');
    });
    test('config bytes', () {
      expect(toHex(Commands.config), '25 AB 02');
    });
    test('battery / serial queries', () {
      expect(Commands.battery, [0x03]);
      expect(Commands.serial, [0x02]);
    });
  });

  group('decoders', () {
    test('handshake reply 20 04 01 is OK', () {
      expect(isHandshakeOk(fromHex('200401')), isTrue);
      expect(isHandshakeOk(fromHex('200400')), isFalse);
      expect(isHandshakeOk(fromHex('03 1E')), isFalse);
    });

    test('battery 03 1E -> 30%', () {
      expect(decodeBattery(fromHex('03 1E')), 30);
    });

    test('battery rejects other opcodes and junk', () {
      expect(decodeBattery(fromHex('04 1E')), isNull);
      expect(decodeBattery([0x03]), isNull);
      expect(decodeBattery(fromHex('03 FF')), isNull);
    });

    test('serial reply -> RH208PBV003416', () {
      expect(decodeSerial(fromHex('025248323038504256303033343136')),
          'RH208PBV003416');
    });
  });

  group('hex helpers', () {
    test('round trip', () {
      expect(fromHex('03:1e'), [0x03, 0x1E]);
      expect(toHex([0x03, 0x1E]), '03 1E');
    });
    test('rejects bad input', () {
      expect(() => fromHex('0'), throwsFormatException);
      expect(() => fromHex('zz'), throwsFormatException);
      expect(() => fromHex(''), throwsFormatException);
    });
  });
}
