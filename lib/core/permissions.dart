import 'package:permission_handler/permission_handler.dart';

enum BlePermissionResult { granted, denied, permanentlyDenied }

/// The only runtime permissions this app asks for: scan and connect.
class BlePermissions {
  static const List<Permission> _required = [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
  ];

  /// Checks the current state without showing a dialog.
  static Future<BlePermissionResult> check() async {
    final statuses = await Future.wait(_required.map((p) => p.status));
    return _combine(statuses);
  }

  /// Shows Android's permission dialog. Both permissions are in the same
  /// "Nearby devices" group, so the user sees a single prompt.
  static Future<BlePermissionResult> request() async {
    final result = await _required.request();
    return _combine(result.values);
  }

  static Future<bool> openSettings() => openAppSettings();

  static BlePermissionResult _combine(Iterable<PermissionStatus> statuses) {
    if (statuses.every((s) => s.isGranted)) return BlePermissionResult.granted;
    if (statuses.any((s) => s.isPermanentlyDenied)) {
      return BlePermissionResult.permanentlyDenied;
    }
    return BlePermissionResult.denied;
  }
}
