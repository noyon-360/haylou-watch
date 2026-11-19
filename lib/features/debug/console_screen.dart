import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ble/ble_log.dart';
import '../../ui/kit.dart';
import '../device/watch_controller.dart';

/// Figma "17 Debug console": raw byte log + hex sender, for reverse-engineering
/// new commands. Factory reset (0x07) is refused by the controller.
class ConsoleScreen extends ConsumerStatefulWidget {
  const ConsoleScreen({super.key});

  @override
  ConsumerState<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends ConsumerState<ConsoleScreen> {
  final _hex = TextEditingController();
  LogDir? _only; // null = all (local view state)

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    try {
      await ref.read(watchControllerProvider.notifier).sendRaw(_hex.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
    }
  }

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ready = ref.watch(watchControllerProvider.select((s) => s.isReady));
    final all = ref.watch(bleLogProvider);
    final entries = _only == null ? all : all.where((e) => e.dir == _only).toList();
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.6);

    Widget filter(String label, LogDir? d) {
      final on = _only == d;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: on ? c.primary : c.surface,
          shape: StadiumBorder(side: BorderSide(color: on ? c.primary : c.border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => setState(() => _only = d),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? c.onPrimary : c.text)),
            ),
          ),
        ),
      );
    }

    return AppPage(
      title: 'Debug console',
      subtitle: const SubtitleText('Raw BLE traffic · → 6001  ← 6002'),
      onBack: () => Navigator.of(context).pop(),
      actions: [
        ChipIconButton(
          icon: Icons.copy_rounded,
          tooltip: 'Copy log',
          onPressed: all.isEmpty
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: all.map((e) => '${_time(e.time)} ${e.dir.name} ${e.text}').join('\n')));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log copied')));
                },
        ),
        ChipIconButton(icon: Icons.delete_outline_rounded, tooltip: 'Clear', onPressed: () => ref.read(bleLogProvider.notifier).clear()),
      ],
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          children: [
            Row(children: [filter('All', null), filter('Sent', LogDir.tx), filter('Received', LogDir.rx), filter('Info', LogDir.info)]),
            const SizedBox(height: 10),
            Expanded(
              child: SurfaceCard(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: entries.isEmpty
                    ? Center(child: Text('No traffic yet', style: TextStyle(color: c.muted)))
                    : ListView.builder(
                        reverse: true,
                        itemCount: entries.length,
                        itemBuilder: (_, i) {
                          final e = entries[entries.length - 1 - i];
                          final (arrow, color) = switch (e.dir) {
                            LogDir.tx => ('→', c.primary),
                            LogDir.rx => ('←', c.success),
                            LogDir.info => ('•', c.muted),
                          };
                          return SelectableText.rich(TextSpan(style: mono.copyWith(color: c.text), children: [
                            TextSpan(text: '${_time(e.time)} ', style: TextStyle(color: c.muted, fontSize: 11)),
                            TextSpan(text: '$arrow ', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                            TextSpan(text: e.text, style: e.dir == LogDir.info ? TextStyle(color: c.muted) : null),
                          ]));
                        },
                      ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                child: Row(children: [
                  Dot(ready ? c.success : c.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _hex,
                      enabled: ready,
                      style: mono,
                      decoration: InputDecoration(hintText: ready ? 'hex, e.g. 03' : 'Connect the watch to send'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: ready ? _send : null, child: const Text('Send')),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
