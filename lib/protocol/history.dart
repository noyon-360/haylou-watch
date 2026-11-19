/// Parsers for the multi-frame history transfers (steps, heart rate, sleep).
/// Each collector is fed every incoming frame and returns true once the
/// watch sent its end marker. Pure Dart, unit-tested with captured frames.
library;

import 'commands.dart';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _u16(List<int> f, int i) => f[i] << 8 | f[i + 1];

/// One hour of step data. Same layout for live `09` and history `0A` frames:
/// `op YYYY MM DD hh total(2) .. .. [10]min [11-12]run .. .. [15]min [16-17]walk`
class StepRecord {
  const StepRecord({
    required this.day,
    required this.hour,
    required this.steps,
    required this.activeMinutes,
  });
  final String day;
  final int hour;
  final int steps;
  final int activeMinutes;
}

StepRecord? decodeStepRecord(List<int> f) {
  if (f.length < 18 || (f[0] != Op.stepHistory && f[0] != Op.liveSteps)) {
    return null;
  }
  if (f[1] == Op.end) return null;
  final date = DateTime(_u16(f, 1), f[3], f[4]);
  final walk = _u16(f, 16);
  final run = _u16(f, 11);
  final total = _u16(f, 6);
  return StepRecord(
    day: dayKey(date),
    hour: f[5],
    // The official app trusts `total`; walk+run is only a cross-check.
    steps: total > 0 ? total : walk + run,
    activeMinutes: f[10] + f[15],
  );
}

class StepHistoryCollector {
  final records = <StepRecord>[];

  bool add(List<int> f) {
    if (f.isEmpty || f[0] != Op.stepHistory) return false;
    if (f.length >= 2 && f[1] == Op.end) return true;
    final r = decodeStepRecord(f);
    if (r != null) records.add(r);
    return false;
  }
}

/// Heart rate: 144 slots per day (one per 10 minutes). Each frame
/// `18 YYYY MM DD hh v0..v11` holds the 2 hours ending at hh;
/// hh = 0 means 24:00 of the previous day. FF/00 = no reading.
class HeartHistoryCollector {
  final days = <String, List<int>>{};

  bool add(List<int> f) {
    if (f.length < 2 || f[0] != Op.heart) return false;
    final b1 = f[1];
    if (b1 == Op.end) return true;
    if (b1 >= 1 && b1 <= 4) return false; // status frames, not history
    if (f.length < 6) return false;
    var date = DateTime(_u16(f, 1), f[3], f[4]);
    var hour = f[5];
    if (hour == 0) {
      date = date.subtract(const Duration(days: 1));
      hour = 24;
    }
    final slots = days.putIfAbsent(dayKey(date), () => List.filled(144, 0));
    for (var i = 0; i < 12 && 6 + i < f.length; i++) {
      final v = f[6 + i];
      final slot = (hour - 2) * 6 + i;
      if (slot < 0 || slot >= 144) continue;
      slots[slot] = (v == 0xFF) ? 0 : v;
    }
    return false;
  }
}

/// Sleep segment types reported by the watch.
enum SleepStage { deep, light, awake, rem, unknown }

SleepStage sleepStageOf(int code) => switch (code) {
      1 => SleepStage.deep,
      2 => SleepStage.light,
      3 => SleepStage.awake,
      4 => SleepStage.rem,
      _ => SleepStage.unknown,
    };

class SleepSegment {
  const SleepSegment({
    required this.hour,
    required this.minute,
    required this.stage,
    required this.minutes,
  });
  final int hour, minute;
  final SleepStage stage;
  final int minutes;
}

/// `1D 01 YYYY MM DD count` starts a night, `1E <bytes>` frames carry
/// count × 6-byte segments `[hh mm type flag dur(2)]`, `1D 02` ends it all.
class SleepHistoryCollector {
  final nights = <String, List<SleepSegment>>{};
  String? _day;
  int _expected = 0;
  final _buf = <int>[];

  bool add(List<int> f) {
    if (f.length < 2) return false;
    if (f[0] == Op.sleep) {
      if (f[1] == 0x02) return true;
      if (f[1] == 0x01 && f.length >= 7) {
        _day = dayKey(DateTime(_u16(f, 2), f[4], f[5]));
        _expected = f[6];
        _buf.clear();
      }
      return false;
    }
    if (f[0] == Op.sleepData && _day != null) {
      _buf.addAll(f.sublist(1));
      if (_buf.length >= _expected * 6) {
        final list = nights.putIfAbsent(_day!, () => []);
        for (var i = 0; i + 6 <= _expected * 6; i += 6) {
          list.add(SleepSegment(
            hour: _buf[i],
            minute: _buf[i + 1],
            stage: sleepStageOf(_buf[i + 2]),
            minutes: _buf[i + 4] << 8 | _buf[i + 5],
          ));
        }
        _day = null;
        _buf.clear();
      }
    }
    return false;
  }
}
