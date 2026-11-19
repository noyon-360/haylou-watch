import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one watch this app is paired with (stored locally only).
class SavedDevice {
  const SavedDevice({required this.id, required this.name});
  final String id; // MAC address, e.g. 78:02:B7:49:7A:C2
  final String name;
}

/// null = no watch saved yet -> show the scan screen.
final savedDeviceProvider =
    AsyncNotifierProvider<SavedDeviceNotifier, SavedDevice?>(
  SavedDeviceNotifier.new,
);

class SavedDeviceNotifier extends AsyncNotifier<SavedDevice?> {
  static const _kId = 'device_id';
  static const _kName = 'device_name';
  final _prefs = SharedPreferencesAsync();

  @override
  Future<SavedDevice?> build() async {
    final id = await _prefs.getString(_kId);
    if (id == null) return null;
    final name = await _prefs.getString(_kName) ?? 'Watch';
    return SavedDevice(id: id, name: name);
  }

  Future<void> save(SavedDevice device) async {
    await _prefs.setString(_kId, device.id);
    await _prefs.setString(_kName, device.name);
    state = AsyncData(device);
  }

  Future<void> clear() async {
    await _prefs.remove(_kId);
    await _prefs.remove(_kName);
    state = const AsyncData(null);
  }
}
