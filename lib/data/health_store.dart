import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../protocol/history.dart';

/// One day of health data synced from the watch.
class DayHealth {
  DayHealth({List<int>? hourlySteps, List<int>? heart, List<SleepSegment>? sleep, this.activeMinutes = 0})
      : hourlySteps = hourlySteps ?? List.filled(24, 0),
        heart = heart ?? List.filled(144, 0),
        sleep = sleep ?? [];

  final List<int> hourlySteps; // 24
  final List<int> heart; // 144 (10-minute slots), 0 = no reading
  final List<SleepSegment> sleep; // night ending on this day
  int activeMinutes;

  int get steps => hourlySteps.fold(0, (a, b) => a + b);

  List<int> get heartReadings => heart.where((v) => v > 0).toList();

  Map<String, Object> toJson() => {
        's': hourlySteps,
        'h': heart,
        'a': activeMinutes,
        'z': [for (final s in sleep) [s.hour, s.minute, s.stage.index, s.minutes]],
      };

  factory DayHealth.fromJson(Map<String, dynamic> j) => DayHealth(
        hourlySteps: (j['s'] as List?)?.cast<int>().toList(),
        heart: (j['h'] as List?)?.cast<int>().toList(),
        activeMinutes: j['a'] as int? ?? 0,
        sleep: [
          for (final z in (j['z'] as List? ?? const []))
            SleepSegment(
              hour: z[0] as int,
              minute: z[1] as int,
              stage: SleepStage.values[z[2] as int],
              minutes: z[3] as int,
            ),
        ],
      );
}

/// Local-only health history, keyed by "YYYY-MM-DD". Keeps [_keepDays].
final healthStoreProvider =
    AsyncNotifierProvider<HealthStore, Map<String, DayHealth>>(HealthStore.new);

class HealthStore extends AsyncNotifier<Map<String, DayHealth>> {
  static const _key = 'health_v1';
  static const _keepDays = 30;
  final _prefs = SharedPreferencesAsync();

  @override
  Future<Map<String, DayHealth>> build() async {
    final raw = await _prefs.getString(_key);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in m.entries) e.key: DayHealth.fromJson(e.value as Map<String, dynamic>)};
    } catch (_) {
      return {};
    }
  }

  Future<void> merge({
    List<StepRecord> steps = const [],
    Map<String, List<int>> heart = const {},
    Map<String, List<SleepSegment>> sleep = const {},
  }) async {
    final days = {...(state.value ?? await future)};
    DayHealth day(String k) => days.putIfAbsent(k, DayHealth.new);

    // Steps arrive per hour; replace each (day, hour) we got.
    final touched = <String>{};
    for (final r in steps) {
      if (r.hour < 0 || r.hour > 23) continue;
      final d = day(r.day);
      if (touched.add(r.day)) d.activeMinutes = 0;
      d.hourlySteps[r.hour] = r.steps;
      d.activeMinutes += r.activeMinutes;
    }
    for (final e in heart.entries) {
      final d = day(e.key);
      for (var i = 0; i < 144; i++) {
        if (e.value[i] > 0) d.heart[i] = e.value[i];
      }
    }
    for (final e in sleep.entries) {
      day(e.key).sleep
        ..clear()
        ..addAll(e.value);
    }

    final keys = days.keys.toList()..sort();
    while (keys.length > _keepDays) {
      days.remove(keys.removeAt(0));
    }
    state = AsyncData(days);
    await _prefs.setString(_key, jsonEncode({for (final e in days.entries) e.key: e.value.toJson()}));
  }

  Future<void> clear() async {
    state = const AsyncData({});
    await _prefs.remove(_key);
  }
}
