import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ble/ble_log.dart';
import '../device/watch_controller.dart';

/// Raw byte log + hex sender, for reverse-engineering new commands.
/// Factory reset (0x07) is refused by the controller.
class ConsoleScreen extends ConsumerStatefulWidget {
  const ConsoleScreen({super.key});

  @override
  ConsumerState<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends ConsumerState<ConsoleScreen> {
  final _hex = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(watchControllerProvider.select((s) => s.isReady));
    final entries = ref.watch(bleLogProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug console'),
        actions: [
          IconButton(
            tooltip: 'Clear',
            onPressed: () => ref.read(bleLogProvider.notifier).clear(),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('→ sent to 6001,  ← received on 6002'),
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No traffic yet'))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: entries.length,
                    itemBuilder: (_, i) {
                      final e = entries[entries.length - 1 - i];
                      final t = e.time;
                      final time =
                          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
                      final (arrow, color) = switch (e.dir) {
                        LogDir.tx => ('→', scheme.primary),
                        LogDir.rx => ('←', Colors.green),
                        LogDir.info => ('•', scheme.outline),
                      };
                      return SelectableText('$time $arrow ${e.text}',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: color));
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hex,
                      enabled: ready,
                      style: const TextStyle(fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: 'hex, e.g. 03',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: ready ? _send : null, child: const Text('Send')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
