import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// UTE/Youcy command service and characteristics (see CLAUDE.md §2).
final Guid watchServiceUuid = Guid('60ff');
final Guid commandCharUuid = Guid('6001'); // phone -> watch (write)
final Guid dataCharUuid = Guid('6002'); // watch -> phone (notify)

/// Secondary service; the official app also enables notifications on 6102.
final Guid secondaryServiceUuid = Guid('61ff');
final Guid secondaryNotifyCharUuid = Guid('6102');

/// ATT MTU the official app negotiates.
const int watchMtu = 247;

/// Name fragments the watch advertises.
/// Confirmed 2026-11-19: the watch advertises "Haylou Smart Watch 2".
/// It does NOT advertise 0x60FF (it advertises 5533, 2222), so never filter scans by 60FF.
const List<String> watchNameHints = ['haylou', 'ls02', 'rh208'];
