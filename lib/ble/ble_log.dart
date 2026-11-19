import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LogDir { tx, rx, info }

class LogEntry {
  const LogEntry(this.time, this.dir, this.text);
  final DateTime time;
  final LogDir dir;
  final String text;
}

/// In-memory log of every byte sent/received (debug console). Never persisted.
final bleLogProvider =
    NotifierProvider<BleLog, List<LogEntry>>(BleLog.new);

class BleLog extends Notifier<List<LogEntry>> {
  static const _max = 300;

  @override
  List<LogEntry> build() => const [];

  void add(LogDir dir, String text) {
    if (kDebugMode) debugPrint('[ble] ${dir.name} $text'); // debug builds only
    final next = [...state, LogEntry(DateTime.now(), dir, text)];
    state = next.length > _max ? next.sublist(next.length - _max) : next;
  }

  void clear() => state = const [];
}
