import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../protocol/commands.dart';

/// Everything the user configures. Stored on this phone only.
class AppSettings {
  const AppSettings({
    this.params = const DeviceParams(),
    this.dnd = const DndSettings(),
    this.sedentary = const SedentarySettings(),
    this.metric = true,
    this.use24h = true,
    this.autoHeart = true,
    this.background = true,
    this.callAlerts = false,
    this.allowedApps = const {},
  });

  final DeviceParams params;
  final DndSettings dnd;
  final SedentarySettings sedentary;
  final bool metric;
  final bool use24h;
  final bool autoHeart;

  /// Keep the watch connected with a foreground service.
  final bool background;

  /// Forward incoming calls (read from the dialer's notification).
  final bool callAlerts;

  /// Package names whose notifications are forwarded. Empty = nothing.
  final Set<String> allowedApps;

  AppSettings copyWith({
    DeviceParams? params,
    DndSettings? dnd,
    SedentarySettings? sedentary,
    bool? metric,
    bool? use24h,
    bool? autoHeart,
    bool? background,
    bool? callAlerts,
    Set<String>? allowedApps,
  }) =>
      AppSettings(
        params: params ?? this.params,
        dnd: dnd ?? this.dnd,
        sedentary: sedentary ?? this.sedentary,
        metric: metric ?? this.metric,
        use24h: use24h ?? this.use24h,
        autoHeart: autoHeart ?? this.autoHeart,
        background: background ?? this.background,
        callAlerts: callAlerts ?? this.callAlerts,
        allowedApps: allowedApps ?? this.allowedApps,
      );

  Map<String, Object> toJson() => {
        'params': params.toJson(),
        'dnd': dnd.toJson(),
        'sed': sedentary.toJson(),
        'metric': metric,
        'h24': use24h,
        'autoHr': autoHeart,
        'bg': background,
        'calls': callAlerts,
        'apps': allowedApps.toList(),
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        params: DeviceParams.fromJson((j['params'] as Map?)?.cast() ?? {}),
        dnd: DndSettings.fromJson((j['dnd'] as Map?)?.cast() ?? {}),
        sedentary: SedentarySettings.fromJson((j['sed'] as Map?)?.cast() ?? {}),
        metric: j['metric'] as bool? ?? true,
        use24h: j['h24'] as bool? ?? true,
        autoHeart: j['autoHr'] as bool? ?? true,
        background: j['bg'] as bool? ?? true,
        callAlerts: j['calls'] as bool? ?? false,
        allowedApps: {...?(j['apps'] as List?)?.cast<String>()},
      );
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  static const _key = 'app_settings_v1';
  final _prefs = SharedPreferencesAsync();

  @override
  Future<AppSettings> build() async {
    final raw = await _prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings(); // corrupt -> defaults
    }
  }

  Future<void> edit(AppSettings Function(AppSettings) change) async {
    final current = state.value ?? await future;
    final next = change(current);
    state = AsyncData(next);
    await _prefs.setString(_key, jsonEncode(next.toJson()));
  }
}
