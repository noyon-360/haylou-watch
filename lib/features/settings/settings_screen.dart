import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/app_settings.dart';
import '../../protocol/commands.dart';
import '../../theme/theme_controller.dart';
import '../../ui/kit.dart';
import '../debug/console_screen.dart';
import '../device/device_screen.dart';
import '../device/watch_controller.dart';
import 'theme_screen.dart';

/// Figma "14 Settings": grouped cards. Values are saved locally first, then
/// pushed to the watch (errors shown as a toast).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsProvider).value;
    final ready = ref.watch(watchControllerProvider.select((w) => w.isReady));
    final season = ref.watch(activeSeasonProvider);
    final auto = ref.watch(themePrefProvider.select((p) => p.value?.auto ?? true));
    final c = context.c;

    if (s == null) {
      return const AppPage(title: 'Settings', body: Center(child: ArcSpinner()));
    }

    final watch = ref.read(watchControllerProvider.notifier);
    final store = ref.read(appSettingsProvider.notifier);

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
    Future<void> format({bool? metric, bool? use24h}) =>
        save((a) => a.copyWith(metric: metric, use24h: use24h), (a) => watch.applyFormat(metric: a.metric, use24h: a.use24h));
    Future<void> dnd(DndSettings Function(DndSettings) f) =>
        save((a) => a.copyWith(dnd: f(a.dnd)), (a) => watch.applyDnd(a.dnd));
    Future<void> sed(SedentarySettings Function(SedentarySettings) f) =>
        save((a) => a.copyWith(sedentary: f(a.sedentary)), (a) => watch.applySedentary(a.sedentary));

    Future<void> pickTime(int h, int m, void Function(int, int) done) async {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: h, minute: m));
      if (t != null) done(t.hour, t.minute);
    }

    final p = s.params;
    final dndRange = '${_t(s.dnd.startHour, s.dnd.startMin)} – ${_t(s.dnd.endHour, s.dnd.endMin)}';
    final sedRange = '${_t(s.sedentary.startHour, s.sedentary.startMin)} – ${_t(s.sedentary.endHour, s.sedentary.endMin)}';
    VoidCallback? on(VoidCallback f) => ready ? f : null;

    return AppPage(
      title: 'Settings',
      subtitle: SubtitleText(ready ? 'Changes are sent to the watch instantly' : 'Watch offline · saved here, sent when it reconnects'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          const SectionLabel('Appearance'),
          GroupCard(children: [
            ValueRow(
              title: 'Theme',
              leading: IconChip(icon: season.icon, size: 36, iconSize: 18),
              subtitle: Text('${auto ? 'Auto' : 'Manual'} · ${season.bn} ${season.en}${auto ? ' — follows the seasons' : ''}',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: c.muted)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ThemeScreen())),
            ),
          ]),
          if (!ready) ...[
            const SizedBox(height: 14),
            SurfaceCard(
              color: c.subtle,
              borderColor: c.subtle,
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 18, color: c.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Connect the watch to change its settings.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text)),
                ),
              ]),
            ),
          ],
          const SectionLabel('Time & units'),
          GroupCard(children: [
            SwitchRow(title: '24-hour clock', value: s.use24h, onChanged: ready ? (v) => format(use24h: v) : null),
            SwitchRow(
              title: 'Metric units',
              subtitle: 'Kilometres and kilograms',
              value: s.metric,
              onChanged: ready ? (v) => format(metric: v) : null,
            ),
          ]),
          const SectionLabel('Display'),
          GroupCard(children: [
            SwitchRow(title: 'Raise to wake', value: p.raiseToWake, onChanged: ready ? (v) => params((x) => x.copyWith(raiseToWake: v)) : null),
            ValueRow(
              title: 'Screen-on time',
              value: '${p.screenOnSec} s',
              onTap: on(() => _choose<int>(context, 'Screen-on time', const [5, 10, 15, 20, 30], p.screenOnSec, (v) => '$v seconds',
                  (v) => params((x) => x.copyWith(screenOnSec: v)))),
            ),
          ]),
          const SectionLabel('Do not disturb'),
          GroupCard(children: [
            SwitchRow(
              title: 'Scheduled quiet hours',
              subtitle: '$dndRange · no vibration',
              value: s.dnd.enabled,
              onChanged: ready ? (v) => dnd((d) => d.copyWith(enabled: v)) : null,
            ),
            ValueRow(
              title: 'Starts',
              value: _t(s.dnd.startHour, s.dnd.startMin),
              onTap: on(() => pickTime(s.dnd.startHour, s.dnd.startMin, (h, m) => dnd((d) => d.copyWith(startHour: h, startMin: m)))),
            ),
            ValueRow(
              title: 'Ends',
              value: _t(s.dnd.endHour, s.dnd.endMin),
              onTap: on(() => pickTime(s.dnd.endHour, s.dnd.endMin, (h, m) => dnd((d) => d.copyWith(endHour: h, endMin: m)))),
            ),
          ]),
          const SectionLabel('Health'),
          GroupCard(children: [
            SwitchRow(
              title: 'Automatic heart rate',
              subtitle: 'Watch measures through the day',
              value: s.autoHeart,
              onChanged: ready ? (v) => save((a) => a.copyWith(autoHeart: v), (a) => watch.applyHeartMode(a.autoHeart)) : null,
            ),
            SwitchRow(
              title: 'Move reminder',
              subtitle: 'Every ${s.sedentary.intervalMin} min, $sedRange',
              value: s.sedentary.enabled,
              onChanged: ready ? (v) => sed((d) => d.copyWith(enabled: v)) : null,
            ),
            ValueRow(
              title: 'Reminder interval',
              value: '${s.sedentary.intervalMin} min',
              onTap: on(() => _choose<int>(context, 'Remind me every', const [30, 45, 60, 90, 120], s.sedentary.intervalMin,
                  (v) => '$v minutes', (v) => sed((d) => d.copyWith(intervalMin: v)))),
            ),
            ValueRow(
              title: 'Active from',
              value: _t(s.sedentary.startHour, s.sedentary.startMin),
              onTap: on(() => pickTime(s.sedentary.startHour, s.sedentary.startMin, (h, m) => sed((d) => d.copyWith(startHour: h, startMin: m)))),
            ),
            ValueRow(
              title: 'Active until',
              value: _t(s.sedentary.endHour, s.sedentary.endMin),
              onTap: on(() => pickTime(s.sedentary.endHour, s.sedentary.endMin, (h, m) => sed((d) => d.copyWith(endHour: h, endMin: m)))),
            ),
          ]),
          const SectionLabel('Profile · for distance & calories'),
          GroupCard(children: [
            _NumberRow(label: 'Height', unit: 'cm', value: p.heightCm, min: 100, max: 230, enabled: ready, onSaved: (v) => params((x) => x.copyWith(heightCm: v))),
            _NumberRow(label: 'Weight', unit: 'kg', value: p.weightKg, min: 25, max: 250, enabled: ready, onSaved: (v) => params((x) => x.copyWith(weightKg: v))),
            _NumberRow(label: 'Age', unit: 'years', value: p.age, min: 5, max: 110, enabled: ready, onSaved: (v) => params((x) => x.copyWith(age: v))),
            _NumberRow(label: 'Daily step goal', unit: 'steps', value: p.stepGoal, min: 1000, max: 50000, enabled: ready, onSaved: (v) => params((x) => x.copyWith(stepGoal: v))),
            ValueRow(
              title: 'Sex',
              value: p.sex == 1 ? 'Male' : 'Female',
              onTap: on(() => _choose<int>(context, 'Sex', const [1, 0], p.sex, (v) => v == 1 ? 'Male' : 'Female',
                  (v) => params((x) => x.copyWith(sex: v)))),
            ),
          ]),
          const SectionLabel('App'),
          GroupCard(children: [
            SwitchRow(
              title: 'Stay connected in background',
              subtitle: 'Shows a small “Connected” notification so Android keeps the link alive',
              value: s.background,
              onChanged: (v) async {
                if (v) await Permission.notification.request();
                await store.edit((a) => a.copyWith(background: v));
              },
            ),
            ValueRow(
              title: 'Debug console',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsoleScreen())),
            ),
            ValueRow(title: 'Forget this watch', danger: true, onTap: () => confirmForget(context, ref)),
          ]),
        ],
      ),
    );
  }
}

String _t(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

/// Bottom sheet with a single-choice list.
Future<void> _choose<T>(BuildContext context, String title, List<T> options, T current, String Function(T) label, void Function(T) onPick) async {
  final picked = await showModalBottomSheet<T>(
    context: context,
    builder: (ctx) {
      final c = ctx.c;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
              ),
              GroupCard(children: [
                for (final o in options)
                  InkWell(
                    onTap: () => Navigator.pop(ctx, o),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      child: Row(children: [
                        Expanded(child: Text(label(o), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.text))),
                        if (o == current) Icon(Icons.check_rounded, color: c.primary, size: 20),
                      ]),
                    ),
                  ),
              ]),
            ],
          ),
        ),
      );
    },
  );
  if (picked != null && picked != current) onPick(picked);
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
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
          OutlinedButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
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
  Widget build(BuildContext context) => ValueRow(
        title: label,
        value: unit == 'steps' ? '$value' : '$value $unit',
        onTap: enabled ? () => _edit(context) : null,
      );
}
