import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/app_settings.dart';
import '../../protocol/commands.dart';
import '../device/watch_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsProvider).value;
    final ready = ref.watch(watchControllerProvider.select((w) => w.isReady));
    if (s == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final watch = ref.read(watchControllerProvider.notifier);
    final store = ref.read(appSettingsProvider.notifier);

    /// Save locally, then push to the watch. Shows an error if the watch didn't ack.
    Future<void> save(AppSettings Function(AppSettings) change, Future<void> Function(AppSettings) push) async {
      await store.edit(change);
      final next = ref.read(appSettingsProvider).value!;
      try {
        await push(next);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Watch did not confirm: $e')));
        }
      }
    }

    Future<void> params(DeviceParams Function(DeviceParams) f) =>
        save((a) => a.copyWith(params: f(a.params)), (a) => watch.applyParams(a.params));
    Future<void> format({bool? metric, bool? use24h}) => save(
        (a) => a.copyWith(metric: metric, use24h: use24h),
        (a) => watch.applyFormat(metric: a.metric, use24h: a.use24h));
    Future<void> dnd(DndSettings Function(DndSettings) f) =>
        save((a) => a.copyWith(dnd: f(a.dnd)), (a) => watch.applyDnd(a.dnd));
    Future<void> sed(SedentarySettings Function(SedentarySettings) f) =>
        save((a) => a.copyWith(sedentary: f(a.sedentary)), (a) => watch.applySedentary(a.sedentary));

    final p = s.params;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (!ready)
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Connect the watch to change its settings'),
            ),
          const _Header('Time & units'),
          SwitchListTile(
            title: const Text('24-hour clock'),
            value: s.use24h,
            onChanged: ready ? (v) => format(use24h: v) : null,
          ),
          SwitchListTile(
            title: const Text('Metric units (km)'),
            value: s.metric,
            onChanged: ready ? (v) => format(metric: v) : null,
          ),
          const _Header('Display'),
          SwitchListTile(
            title: const Text('Raise to wake'),
            value: p.raiseToWake,
            onChanged: ready ? (v) => params((x) => x.copyWith(raiseToWake: v)) : null,
          ),
          ListTile(
            title: const Text('Screen-on time'),
            trailing: DropdownButton<int>(
              value: const [5, 10, 15, 20, 30].contains(p.screenOnSec) ? p.screenOnSec : null,
              hint: Text('${p.screenOnSec} s'),
              items: [for (final v in const [5, 10, 15, 20, 30]) DropdownMenuItem(value: v, child: Text('$v s'))],
              onChanged: ready ? (v) => params((x) => x.copyWith(screenOnSec: v)) : null,
            ),
          ),
          const _Header('Do not disturb'),
          SwitchListTile(
            title: const Text('Scheduled DND'),
            subtitle: Text('${_t(s.dnd.startHour, s.dnd.startMin)} – ${_t(s.dnd.endHour, s.dnd.endMin)}'),
            value: s.dnd.enabled,
            onChanged: ready ? (v) => dnd((d) => d.copyWith(enabled: v)) : null,
          ),
          _TimeRange(
            enabled: ready,
            start: (s.dnd.startHour, s.dnd.startMin),
            end: (s.dnd.endHour, s.dnd.endMin),
            onStart: (h, m) => dnd((d) => d.copyWith(startHour: h, startMin: m)),
            onEnd: (h, m) => dnd((d) => d.copyWith(endHour: h, endMin: m)),
          ),
          const _Header('Health'),
          SwitchListTile(
            title: const Text('Automatic heart-rate monitoring'),
            subtitle: const Text('Watch measures through the day'),
            value: s.autoHeart,
            onChanged: ready
                ? (v) => save((a) => a.copyWith(autoHeart: v), (a) => watch.applyHeartMode(a.autoHeart))
                : null,
          ),
          SwitchListTile(
            title: const Text('Move reminder'),
            subtitle: Text('Every ${s.sedentary.intervalMin} min, '
                '${_t(s.sedentary.startHour, s.sedentary.startMin)} – ${_t(s.sedentary.endHour, s.sedentary.endMin)}'),
            value: s.sedentary.enabled,
            onChanged: ready ? (v) => sed((d) => d.copyWith(enabled: v)) : null,
          ),
          ListTile(
            title: const Text('Reminder interval'),
            trailing: DropdownButton<int>(
              value: const [30, 45, 60, 90, 120].contains(s.sedentary.intervalMin) ? s.sedentary.intervalMin : null,
              items: [for (final v in const [30, 45, 60, 90, 120]) DropdownMenuItem(value: v, child: Text('$v min'))],
              onChanged: ready ? (v) => sed((d) => d.copyWith(intervalMin: v)) : null,
            ),
          ),
          _TimeRange(
            enabled: ready,
            start: (s.sedentary.startHour, s.sedentary.startMin),
            end: (s.sedentary.endHour, s.sedentary.endMin),
            onStart: (h, m) => sed((d) => d.copyWith(startHour: h, startMin: m)),
            onEnd: (h, m) => sed((d) => d.copyWith(endHour: h, endMin: m)),
          ),
          const _Header('Profile (used for distance & calories)'),
          _NumberTile(label: 'Height', unit: 'cm', value: p.heightCm, min: 100, max: 230, enabled: ready,
              onSaved: (v) => params((x) => x.copyWith(heightCm: v))),
          _NumberTile(label: 'Weight', unit: 'kg', value: p.weightKg, min: 25, max: 250, enabled: ready,
              onSaved: (v) => params((x) => x.copyWith(weightKg: v))),
          _NumberTile(label: 'Age', unit: 'years', value: p.age, min: 5, max: 110, enabled: ready,
              onSaved: (v) => params((x) => x.copyWith(age: v))),
          _NumberTile(label: 'Daily step goal', unit: 'steps', value: p.stepGoal, min: 1000, max: 50000, enabled: ready,
              onSaved: (v) => params((x) => x.copyWith(stepGoal: v))),
          ListTile(
            title: const Text('Sex'),
            trailing: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Male')),
                ButtonSegment(value: 0, label: Text('Female')),
              ],
              selected: {p.sex},
              onSelectionChanged: ready ? (v) => params((x) => x.copyWith(sex: v.first)) : null,
            ),
          ),
          const _Header('App'),
          SwitchListTile(
            title: const Text('Stay connected in background'),
            subtitle: const Text('Shows a small "Connected" notification so Android keeps the link alive'),
            value: s.background,
            onChanged: (v) async {
              if (v) await Permission.notification.request();
              await store.edit((a) => a.copyWith(background: v));
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

String _t(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

class _TimeRange extends StatelessWidget {
  const _TimeRange({
    required this.enabled,
    required this.start,
    required this.end,
    required this.onStart,
    required this.onEnd,
  });
  final bool enabled;
  final (int, int) start, end;
  final void Function(int h, int m) onStart, onEnd;

  Future<void> _pick(BuildContext context, (int, int) init, void Function(int, int) done) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: init.$1, minute: init.$2));
    if (t != null) done(t.hour, t.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: enabled ? () => _pick(context, start, onStart) : null,
              child: Text('From ${_t(start.$1, start.$2)}'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: enabled ? () => _pick(context, end, onEnd) : null,
              child: Text('To ${_t(end.$1, end.$2)}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberTile extends StatelessWidget {
  const _NumberTile({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onSaved,
  });
  final String label, unit;
  final int value, min, max;
  final bool enabled;
  final void Function(int) onSaved;

  Future<void> _edit(BuildContext context) async {
    final ctrl = TextEditingController(text: '$value');
    final result = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(suffixText: unit, helperText: '$min – $max'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text);
              if (v != null && v >= min && v <= max) Navigator.pop(c, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result != value) onSaved(result);
  }

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label),
        trailing: Text('$value $unit'),
        enabled: enabled,
        onTap: () => _edit(context),
      );
}
