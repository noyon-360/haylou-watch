import 'package:flutter_test/flutter_test.dart';
import 'package:watch/core/hex.dart';
import 'package:watch/protocol/commands.dart';
import 'package:watch/protocol/history.dart';

/// Every expected byte string below was sent/received by the official app in
/// the HCI capture (CLAUDE.md §2), except where marked "synthetic".
void main() {
  group('encoders reproduce captured frames', () {
    test('set time 2026-11-19 20:05:09, UTC+6', () {
      expect(
          toHex(Commands.setTime(DateTime(2026, 11, 19, 20, 5, 9),
              utcOffset: const Duration(hours: 6))),
          '04 07 EA 0B 13 14 05 09 06');
    });

    test('format: metric + 12h / 24h', () {
      expect(toHex(Commands.format(metric: true, use24h: false)), '01 01 02');
      expect(toHex(Commands.format(metric: true, use24h: true)), '01 01 01');
    });

    test('device params (raise on / off, 10 s screen)', () {
      const p = DeviceParams(language: 1, maxHeartAlert: 160, minHeartAlert: 40);
      expect(toHex(Commands.params(p)),
          '05 00 AE 00 46 0F 00 00 1F 40 01 A0 00 19 01 00 01 01 28');
      expect(toHex(Commands.params(p.copyWith(raiseToWake: false))),
          '05 00 AE 00 46 0F 00 00 1F 40 00 A0 00 19 01 00 01 01 28');
      expect(toHex(Commands.params(p.copyWith(screenOnSec: 10))),
          '05 00 AE 00 46 0A 00 00 1F 40 01 A0 00 19 01 00 01 01 28');
    });

    test('DND 22:00-07:00 on/off', () {
      const s = DndSettings(enabled: true, startHour: 22, endHour: 7);
      expect(toHex(Commands.dnd(s)), '15 00 16 00 07 00 01');
      expect(toHex(Commands.dnd(s.copyWith(enabled: false))), '15 00 16 00 07 00 00');
    });

    test('heart mode, find watch, quick switch', () {
      expect(toHex(Commands.heartMode(auto: true)), '18 01');
      expect(toHex(Commands.heartMode(auto: false)), '18 02');
      expect(toHex(Commands.findWatch), '06 00 00 00 01 02 07 01');
      expect(toHex(Commands.quickSwitch), '0C 02');
    });

    test('history requests', () {
      expect(toHex(Commands.stepHistory(DateTime(2026, 11, 13))), '0A 07 EA 0B 0D 00 00');
      expect(toHex(Commands.sleepHistory(DateTime(2026, 11, 12))), '1D 01 07 EA 0B 0C 00');
      expect(toHex(Commands.heartHistory(DateTime(2026, 11, 18))), '18 FA 07 EA 0B 12');
    });

    test('factory reset is blocked', () {
      expect(blockedOpcodes, contains(0x07));
    });
  });

  group('decoders on captured replies', () {
    test('quick switches 0C 02 42 -> raise on, others off', () {
      final q = decodeQuickSwitches(fromHex('0c02420000000000000000000000000000000000'))!;
      expect(q.raiseToWake, isTrue);
      expect(q.sedentary, isFalse);
      expect(q.dnd, isFalse);
    });

    test('live heart rate 16 11 00 54 -> 84 bpm', () {
      expect(decodeLiveHeart(fromHex('16110054')), 84);
      expect(decodeLiveHeart(fromHex('1611')), isNull);
    });

    test('find phone button 12 0A', () {
      expect(decodeFindPhone(fromHex('120a')), FindPhone.toggle);
      expect(decodeFindPhone(fromHex('120a01')), FindPhone.start);
      expect(decodeFindPhone(fromHex('120a00')), FindPhone.stop);
    });

    test('heart history: 92 bpm at 17:40 on 2026-11-19', () {
      final c = HeartHistoryCollector();
      expect(c.add(fromHex('180407ea0b13140863545b')), isFalse); // status, ignored
      expect(c.add(fromHex('1807ea0b1312ffffffffffffffffffff5cff')), isFalse);
      expect(c.add(fromHex('1807ea0b1314ffffffffffffffffffffffff')), isFalse);
      expect(c.add(fromHex('18fda5')), isTrue);
      final day = c.days['2026-11-19']!;
      expect(day[106], 92); // slot 106 * 10 min = 17:40
      expect(day.where((v) => v > 0).length, 1);
    });

    test('empty step / sleep history ends', () {
      final s = StepHistoryCollector();
      expect(s.add(fromHex('0afd00')), isTrue);
      expect(s.records, isEmpty);
      final z = SleepHistoryCollector();
      expect(z.add(fromHex('1d02')), isTrue);
    });

    test('step record (synthetic, captured layout)', () {
      // 2026-11-19 08:00, total 1234, run 200, walk 1034, 12+3 active min
      final f = fromHex('0a07ea0b1308 04d2 0000 0c 00c8 0000 03 040a');
      final r = decodeStepRecord(f)!;
      expect(r.day, '2026-11-19');
      expect(r.hour, 8);
      expect(r.steps, 1234);
      expect(r.activeMinutes, 15);
    });

    test('sleep night (synthetic, official layout)', () {
      final c = SleepHistoryCollector();
      c.add(fromHex('1d0107ea0b1302')); // 2026-11-19, 2 segments
      c.add(fromHex('1e 17 1e 02 00 00 3c 00 1e 01 00 00 5a')); // 23:30 light 60, 00:30 deep 90
      expect(c.add(fromHex('1d02')), isTrue);
      final n = c.nights['2026-11-19']!;
      expect(n.length, 2);
      expect(n[0].stage, SleepStage.light);
      expect(n[0].minutes, 60);
      expect(n[1].stage, SleepStage.deep);
      expect(n[1].hour, 0);
      expect(n[1].minutes, 90);
    });
  });

  group('notification framing', () {
    test('short message fits in one packet + end marker', () {
      final frames = messageFrames(MsgType.whatsapp, 'Al', 'Hi');
      expect(frames.map(toHex).toList(), [
        '0F 00 07 0C 00 41 00 6C 00 3A 00 20 00 48 00 69', // "Al: Hi"
        '0F FD',
      ]);
    });

    test('long message is split: 16 bytes, then 18-byte continuations', () {
      final frames = messageFrames(MsgType.other, '', 'abcdefghijklmnopqrst'); // 40 bytes
      expect(frames.length, 4);
      expect(frames[0].length, 20);
      expect(frames[0].sublist(0, 4), [0x0F, 0x00, 0x04, 40]);
      expect(frames[1].sublist(0, 2), [0x0F, 0x01]);
      expect(frames[1].length, 20);
      expect(frames[2].sublist(0, 2), [0x0F, 0x02]);
      expect(frames[2].length, 2 + 6);
      expect(toHex(frames[3]), '0F FD');
    });

    test('text is capped at 254 bytes (even, no broken char)', () {
      final p = utf16be('x' * 500, 254);
      expect(p.length, 254);
    });

    test('SMS sends body in 0F and sender in 10', () {
      final frames = messageFrames(MsgType.sms, 'Mom', 'ok');
      expect(frames.first.sublist(0, 4), [0x0F, 0, 3, 4]);
      expect(frames.any((f) => f[0] == 0x10 && f[1] == 0), isTrue);
      expect(toHex(frames.last), '10 FD');
    });

    test('call alert uses type 0 and caps name at 30 bytes', () {
      final frames = callFrames('A very long caller name here');
      expect(frames.first.sublist(0, 4), [0x0F, 0, 0, 30]);
    });
  });
}
