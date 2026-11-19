/// Pure-Dart protocol frames for the UTE/Youcy watch protocol.
/// No BLE here, so everything is unit-testable (see test/protocol/).
///
/// Frame format: raw `[opcode][payload…]`, no length/CRC.
/// The watch replies on 0x6002 with the same first byte (opcode echo).
/// Byte layouts were confirmed against the HCI capture (CLAUDE.md §2).
library;

import 'dart:convert';
import 'dart:typed_data';

abstract final class Op {
  static const int format = 0x01; // 01 <distance> <time>
  static const int serial = 0x02;
  static const int battery = 0x03;
  static const int setTime = 0x04;
  static const int params = 0x05; // user profile + display
  static const int vibrate = 0x06; // find my watch
  static const int factoryReset = 0x07; // NEVER sent by this app
  static const int liveSteps = 0x09;
  static const int stepHistory = 0x0A;
  static const int quickSwitch = 0x0C;
  static const int callEnd = 0x0D;
  static const int message = 0x0F;
  static const int messageSender = 0x10;
  static const int key = 0x12; // button events from the watch (find phone)
  static const int sedentary = 0x14;
  static const int dnd = 0x15;
  static const int liveHeart = 0x16;
  static const int heart = 0x18; // 18 01/02 = HR mode, 18 FA … = history
  static const int sleep = 0x1D;
  static const int sleepData = 0x1E;
  static const int handshake = 0x20;
  static const int config = 0x25;

  /// End-of-transfer marker used in history/message streams.
  static const int end = 0xFD;
}

/// Opcodes the raw console refuses to send (irreversible / risky).
const Set<int> blockedOpcodes = {Op.factoryReset};

abstract final class Commands {
  /// Sent first on every connect (captured; assumed static — see CLAUDE.md §10).
  static const List<int> handshake = [0x20, 0x02, 0x05, 0x61, 0x97, 0x4A];

  /// Sent right after the handshake by the official app.
  static const List<int> config = [0x25, 0xAB, 0x02];

  static const List<int> battery = [Op.battery];
  static const List<int> serial = [Op.serial];
  static const List<int> quickSwitch = [Op.quickSwitch, 0x02];

  /// Find my watch: vibrate + light. Captured `06 00 00 00 01 02 07 01`.
  static const List<int> findWatch = [0x06, 0, 0, 0, 0x01, 0x02, 0x07, 0x01];
  static const List<int> stopFindWatch = [0x06, 0, 0, 0, 0, 0, 0, 0];

  /// Stops the incoming-call alert on the watch.
  static const List<int> callEnd = [Op.callEnd, 0x04];

  /// `04 YYYY MM DD hh mm ss tz` — tz = UTC offset in whole hours
  /// (captured `06` from a UTC+6 phone). Local wall-clock time.
  static List<int> setTime(DateTime t, {Duration? utcOffset}) => [
        Op.setTime,
        t.year >> 8 & 0xFF,
        t.year & 0xFF,
        t.month,
        t.day,
        t.hour,
        t.minute,
        t.second,
        (utcOffset ?? t.timeZoneOffset).inHours & 0xFF,
      ];

  /// `01 <distance 1=metric 2=imperial> <time 1=24h 2=12h>`.
  static List<int> format({required bool metric, required bool use24h}) =>
      [Op.format, metric ? 1 : 2, use24h ? 1 : 2];

  /// `18 01` = automatic heart-rate measuring, `18 02` = manual only.
  static List<int> heartMode({required bool auto}) => [Op.heart, auto ? 1 : 2];

  /// `15 00 sh sm eh em on`.
  static List<int> dnd(DndSettings s) =>
      [Op.dnd, 0, s.startHour, s.startMin, s.endHour, s.endMin, s.enabled ? 1 : 0];

  /// `14 on interval 02 05 00 00 sh sm eh em noonOff` (layout from the official app).
  static List<int> sedentary(SedentarySettings s) => [
        Op.sedentary,
        s.enabled ? 1 : 0,
        s.intervalMin.clamp(15, 240),
        0x02,
        0x05,
        0,
        0,
        s.startHour,
        s.startMin,
        s.endHour,
        s.endMin,
        s.skipNoon ? 1 : 0,
      ];

  /// 19-byte `05` frame: profile + screen-on time + raise-to-wake.
  static List<int> params(DeviceParams p) => [
        Op.params,
        p.heightCm >> 8 & 0xFF,
        p.heightCm & 0xFF,
        p.weightKg >> 8 & 0xFF,
        p.weightKg & 0xFF,
        p.screenOnSec,
        p.stepGoal >> 24 & 0xFF,
        p.stepGoal >> 16 & 0xFF,
        p.stepGoal >> 8 & 0xFF,
        p.stepGoal & 0xFF,
        p.raiseToWake ? 1 : 0,
        p.maxHeartAlert,
        0,
        p.age,
        p.sex,
        0, // device-lost warning: off
        p.language,
        p.tempUnit,
        p.minHeartAlert,
      ];

  /// History requests: the watch sends every record from [since] onward.
  static List<int> stepHistory(DateTime since) =>
      [Op.stepHistory, ..._ymd(since), 0, 0];
  static List<int> heartHistory(DateTime since) =>
      [Op.heart, 0xFA, ..._ymd(since)];
  static List<int> sleepHistory(DateTime since) =>
      [Op.sleep, 0x01, ..._ymd(since), 0];

  static List<int> _ymd(DateTime d) =>
      [d.year >> 8 & 0xFF, d.year & 0xFF, d.month, d.day];
}

class DeviceParams {
  const DeviceParams({
    this.heightCm = 174,
    this.weightKg = 70,
    this.age = 25,
    this.sex = 1,
    this.stepGoal = 8000,
    this.screenOnSec = 15,
    this.raiseToWake = true,
    this.maxHeartAlert = 160,
    this.minHeartAlert = 40,
    this.language = 2,
    this.tempUnit = 1,
  });

  final int heightCm;
  final int weightKg;
  final int age;
  final int sex; // 1 = male, 0 = female (unverified)
  final int stepGoal;
  final int screenOnSec;
  final bool raiseToWake;
  final int maxHeartAlert;
  final int minHeartAlert;
  /// Always 2 (English): other codes are acked by the watch but change nothing.
  final int language;
  final int tempUnit;

  DeviceParams copyWith({
    int? heightCm,
    int? weightKg,
    int? age,
    int? sex,
    int? stepGoal,
    int? screenOnSec,
    bool? raiseToWake,
  }) =>
      DeviceParams(
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        age: age ?? this.age,
        sex: sex ?? this.sex,
        stepGoal: stepGoal ?? this.stepGoal,
        screenOnSec: screenOnSec ?? this.screenOnSec,
        raiseToWake: raiseToWake ?? this.raiseToWake,
        maxHeartAlert: maxHeartAlert,
        minHeartAlert: minHeartAlert,
        language: language,
        tempUnit: tempUnit,
      );

  Map<String, Object> toJson() => {
        'h': heightCm,
        'w': weightKg,
        'age': age,
        'sex': sex,
        'goal': stepGoal,
        'screen': screenOnSec,
        'raise': raiseToWake,
      };

  factory DeviceParams.fromJson(Map<String, dynamic> j) {
    const d = DeviceParams();
    return DeviceParams(
      heightCm: j['h'] as int? ?? d.heightCm,
      weightKg: j['w'] as int? ?? d.weightKg,
      age: j['age'] as int? ?? d.age,
      sex: j['sex'] as int? ?? d.sex,
      stepGoal: j['goal'] as int? ?? d.stepGoal,
      screenOnSec: j['screen'] as int? ?? d.screenOnSec,
      raiseToWake: j['raise'] as bool? ?? d.raiseToWake,
    );
  }
}

class DndSettings {
  const DndSettings({
    this.enabled = false,
    this.startHour = 22,
    this.startMin = 0,
    this.endHour = 7,
    this.endMin = 0,
  });
  final bool enabled;
  final int startHour, startMin, endHour, endMin;

  DndSettings copyWith({bool? enabled, int? startHour, int? startMin, int? endHour, int? endMin}) =>
      DndSettings(
        enabled: enabled ?? this.enabled,
        startHour: startHour ?? this.startHour,
        startMin: startMin ?? this.startMin,
        endHour: endHour ?? this.endHour,
        endMin: endMin ?? this.endMin,
      );

  Map<String, Object> toJson() =>
      {'on': enabled, 'sh': startHour, 'sm': startMin, 'eh': endHour, 'em': endMin};
  factory DndSettings.fromJson(Map<String, dynamic> j) => DndSettings(
        enabled: j['on'] as bool? ?? false,
        startHour: j['sh'] as int? ?? 22,
        startMin: j['sm'] as int? ?? 0,
        endHour: j['eh'] as int? ?? 7,
        endMin: j['em'] as int? ?? 0,
      );
}

class SedentarySettings {
  const SedentarySettings({
    this.enabled = false,
    this.intervalMin = 60,
    this.startHour = 9,
    this.startMin = 0,
    this.endHour = 18,
    this.endMin = 0,
    this.skipNoon = true,
  });
  final bool enabled;
  final int intervalMin;
  final int startHour, startMin, endHour, endMin;
  final bool skipNoon;

  SedentarySettings copyWith({
    bool? enabled,
    int? intervalMin,
    int? startHour,
    int? startMin,
    int? endHour,
    int? endMin,
    bool? skipNoon,
  }) =>
      SedentarySettings(
        enabled: enabled ?? this.enabled,
        intervalMin: intervalMin ?? this.intervalMin,
        startHour: startHour ?? this.startHour,
        startMin: startMin ?? this.startMin,
        endHour: endHour ?? this.endHour,
        endMin: endMin ?? this.endMin,
        skipNoon: skipNoon ?? this.skipNoon,
      );

  Map<String, Object> toJson() => {
        'on': enabled,
        'iv': intervalMin,
        'sh': startHour,
        'sm': startMin,
        'eh': endHour,
        'em': endMin,
        'noon': skipNoon,
      };
  factory SedentarySettings.fromJson(Map<String, dynamic> j) => SedentarySettings(
        enabled: j['on'] as bool? ?? false,
        intervalMin: j['iv'] as int? ?? 60,
        startHour: j['sh'] as int? ?? 9,
        startMin: j['sm'] as int? ?? 0,
        endHour: j['eh'] as int? ?? 18,
        endMin: j['em'] as int? ?? 0,
        skipNoon: j['noon'] as bool? ?? true,
      );
}

// ---------------------------------------------------------------------------
// Notifications (opcode 0F) and incoming calls
// ---------------------------------------------------------------------------

/// App-type codes the watch understands (icon shown on the watch).
abstract final class MsgType {
  static const int call = 0;
  static const int qq = 1;
  static const int wechat = 2;
  static const int sms = 3;
  static const int other = 4;
  static const int facebook = 5;
  static const int twitter = 6;
  static const int whatsapp = 7;
  static const int skype = 8;
  static const int messenger = 9;
  static const int line = 11;
  static const int linkedin = 12;
  static const int instagram = 13;
  static const int viber = 14;
  static const int snapchat = 17;
  static const int gmail = 19;
  static const int youtube = 23;
  static const int telegram = 24;
}

/// UTF-16BE (what the watch expects), cut at [maxBytes] on a char boundary.
Uint8List utf16be(String s, int maxBytes) {
  final out = BytesBuilder();
  for (final unit in s.codeUnits) {
    if (out.length + 2 > maxBytes) break;
    out.addByte(unit >> 8);
    out.addByte(unit & 0xFF);
  }
  return out.toBytes();
}

/// Splits [payload] into ≤20-byte packets:
/// `op 00 type len <16 bytes>`, then `op seq <18 bytes>`…, then `op FD`.
List<List<int>> packMessage(int op, int type, List<int> payload) {
  final frames = <List<int>>[];
  final first = payload.length <= 16 ? payload : payload.sublist(0, 16);
  frames.add([op, 0, type, payload.length & 0xFF, ...first]);
  var seq = 1;
  for (var i = 16; i < payload.length; i += 18) {
    final end = i + 18 < payload.length ? i + 18 : payload.length;
    frames.add([op, seq++, ...payload.sublist(i, end)]);
  }
  frames.add([op, Op.end]);
  return frames;
}

/// Frames for one phone notification. Text is "title: body" (≤254 bytes).
/// SMS (type 3) is special: body in 0F frames, sender in 10 frames.
List<List<int>> messageFrames(int type, String title, String body) {
  if (type == MsgType.sms) {
    return [
      ...packMessage(Op.message, type, utf16be(body, 254)),
      ...packMessage(Op.messageSender, type, utf16be(title, 30)),
    ];
  }
  final text = title.isEmpty ? body : (body.isEmpty ? title : '$title: $body');
  return packMessage(Op.message, type, utf16be(text, 254));
}

/// Incoming-call alert showing [caller] (≤30 bytes).
List<List<int>> callFrames(String caller) =>
    packMessage(Op.message, MsgType.call, utf16be(caller, 30));

// ---------------------------------------------------------------------------
// Decoders
// ---------------------------------------------------------------------------

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

class QuickSwitches {
  const QuickSwitches({required this.raiseToWake, required this.sedentary, required this.dnd});
  final bool raiseToWake, sedentary, dnd;
}

/// `0C 02 <bits>`: bit1 raise-to-wake, bit2 sedentary reminder, bit3 DND.
QuickSwitches? decodeQuickSwitches(List<int> frame) {
  if (frame.length < 3 || frame[0] != Op.quickSwitch) return null;
  final b = frame[2];
  return QuickSwitches(
    raiseToWake: b >> 1 & 1 == 1,
    sedentary: b >> 2 & 1 == 1,
    dnd: b >> 3 & 1 == 1,
  );
}

/// Live heart rate push `16 11 00 <bpm>`. null for status-only frames.
int? decodeLiveHeart(List<int> frame) {
  if (frame.length < 4 || frame[0] != Op.liveHeart || frame[2] != 0) return null;
  final bpm = frame[3];
  return (bpm == 0 || bpm == 0xFF) ? null : bpm;
}

/// Find-phone button on the watch: `12 0A` (toggle), `12 0A 01` start, `12 0A 00` stop.
enum FindPhone { toggle, start, stop }

FindPhone? decodeFindPhone(List<int> frame) {
  if (frame.length < 2 || frame[0] != Op.key || frame[1] != 0x0A) return null;
  if (frame.length == 2) return FindPhone.toggle;
  final v = frame[frame.length - 1];
  return v == 1 ? FindPhone.start : (v == 0 ? FindPhone.stop : FindPhone.toggle);
}
