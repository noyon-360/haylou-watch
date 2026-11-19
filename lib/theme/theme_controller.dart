import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'season.dart';

/// Auto = follow the Bengali calendar; otherwise use [manual].
class ThemePref {
  const ThemePref({this.auto = true, this.manual = Season.hemanta});
  final bool auto;
  final Season manual;

  ThemePref copyWith({bool? auto, Season? manual}) =>
      ThemePref(auto: auto ?? this.auto, manual: manual ?? this.manual);
}

final themePrefProvider = AsyncNotifierProvider<ThemePrefNotifier, ThemePref>(ThemePrefNotifier.new);

class ThemePrefNotifier extends AsyncNotifier<ThemePref> {
  static const _kAuto = 'theme_auto';
  static const _kManual = 'theme_manual';
  final _prefs = SharedPreferencesAsync();

  @override
  Future<ThemePref> build() async {
    final auto = await _prefs.getBool(_kAuto) ?? true;
    final name = await _prefs.getString(_kManual);
    final manual = Season.values.where((s) => s.name == name).firstOrNull ?? BengaliCalendar.seasonOf(DateTime.now());
    return ThemePref(auto: auto, manual: manual);
  }

  Future<void> setAuto(bool auto) async {
    final cur = state.value ?? await future;
    // When leaving auto, start from the season currently shown.
    final manual = auto ? cur.manual : BengaliCalendar.seasonOf(ref.read(todayProvider));
    state = AsyncData(cur.copyWith(auto: auto, manual: auto ? null : manual));
    await _prefs.setBool(_kAuto, auto);
    if (!auto) await _prefs.setString(_kManual, manual.name);
  }

  /// Picking a season turns auto off.
  Future<void> pick(Season s) async {
    final cur = state.value ?? await future;
    state = AsyncData(cur.copyWith(auto: false, manual: s));
    await _prefs.setBool(_kAuto, false);
    await _prefs.setString(_kManual, s.name);
  }
}

/// Today's date. Ticks at local midnight and when the app is resumed, so an
/// automatic season change happens without restarting the app.
final todayProvider = NotifierProvider<TodayNotifier, DateTime>(TodayNotifier.new);

class TodayNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final listener = AppLifecycleListener(onResume: _refresh);
    ref.onDispose(() {
      _timer?.cancel();
      listener.dispose();
    });
    _schedule();
    return _today();
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _refresh() {
    final t = _today();
    if (t != state) state = t;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    _timer = Timer(midnight.difference(now), _refresh);
  }
}

/// The season that drives the theme and the logo colour right now.
final activeSeasonProvider = Provider<Season>((ref) {
  final pref = ref.watch(themePrefProvider).value ?? const ThemePref();
  if (!pref.auto) return pref.manual;
  return BengaliCalendar.seasonOf(ref.watch(todayProvider));
});

/// The calendar season for today (what auto mode would show).
final calendarSeasonProvider = Provider<Season>((ref) => BengaliCalendar.seasonOf(ref.watch(todayProvider)));
