import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_settings.dart';
import '../../data/health_store.dart';
import '../../protocol/history.dart';
import '../device/watch_controller.dart';

class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  int _daysAgo = 0;

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(healthStoreProvider).value ?? const {};
    final settings = ref.watch(appSettingsProvider).value ?? const AppSettings();
    final watch = ref.watch(watchControllerProvider);
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: _daysAgo));
    final day = days[dayKey(date)] ?? DayHealth();

    final title = _daysAgo == 0
        ? 'Today'
        : _daysAgo == 1
            ? 'Yesterday'
            : '${date.day}/${date.month}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health'),
        actions: [
          IconButton(
            tooltip: 'Sync from watch',
            onPressed: watch.isReady && !watch.syncing
                ? () => ref.read(watchControllerProvider.notifier).syncHealth()
                : null,
            icon: watch.syncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _daysAgo < 29 ? () => setState(() => _daysAgo++) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              SizedBox(
                width: 120,
                child: Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                onPressed: _daysAgo > 0 ? () => setState(() => _daysAgo--) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          _StepsCard(day: day, settings: settings),
          _HeartCard(day: day, live: _daysAgo == 0 ? watch.liveHeart : null),
          _SleepCard(segments: day.sleep),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.day, required this.settings});
  final DayHealth day;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final p = settings.params;
    final steps = day.steps;
    final goal = max(1, p.stepGoal);
    // Estimates: stride ≈ 0.415 × height; energy ≈ 0.5 kcal per kg per km walked.
    final km = steps * p.heightCm * 0.415 / 100000;
    final kcal = km * p.weightKg * 0.5;
    final dist = settings.metric ? '${km.toStringAsFixed(2)} km' : '${(km * 0.621).toStringAsFixed(2)} mi';
    final scheme = Theme.of(context).colorScheme;

    return _Section(
      icon: Icons.directions_walk,
      title: 'Steps',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$steps', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('/ $goal'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: min(1, steps / goal), minHeight: 8, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 8),
        Text('≈ $dist · ≈ ${kcal.round()} kcal · ${day.activeMinutes} active min',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BarsPainter(day.hourlySteps, scheme.primary, scheme.outlineVariant),
          ),
        ),
        const _HourAxis(),
      ],
    );
  }
}

class _HeartCard extends StatelessWidget {
  const _HeartCard({required this.day, this.live});
  final DayHealth day;
  final int? live;

  @override
  Widget build(BuildContext context) {
    final r = day.heartReadings;
    final summary = r.isEmpty
        ? 'No readings'
        : 'min ${r.reduce(min)} · avg ${(r.reduce((a, b) => a + b) / r.length).round()} · max ${r.reduce(max)} bpm';
    return _Section(
      icon: Icons.favorite,
      iconColor: Colors.red,
      title: 'Heart rate',
      trailing: live == null ? null : Text('Live $live bpm'),
      children: [
        Text(summary),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: CustomPaint(
            size: Size.infinite,
            painter: _DotsPainter(day.heart, Colors.red, Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        const _HourAxis(),
      ],
    );
  }
}

class _SleepCard extends StatelessWidget {
  const _SleepCard({required this.segments});
  final List<SleepSegment> segments;

  static const colors = {
    SleepStage.deep: Color(0xFF3949AB),
    SleepStage.light: Color(0xFF64B5F6),
    SleepStage.rem: Color(0xFF26A69A),
    SleepStage.awake: Color(0xFFFFB74D),
    SleepStage.unknown: Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return const _Section(icon: Icons.bedtime, title: 'Sleep', children: [Text('No sleep recorded')]);
    }
    final byStage = <SleepStage, int>{};
    for (final s in segments) {
      byStage[s.stage] = (byStage[s.stage] ?? 0) + s.minutes;
    }
    final asleep = segments.where((s) => s.stage != SleepStage.awake).fold(0, (a, s) => a + s.minutes);
    final total = segments.fold(0, (a, s) => a + s.minutes);
    final first = segments.first;
    String hm(int m) => '${m ~/ 60}h ${m % 60}m';

    return _Section(
      icon: Icons.bedtime,
      title: 'Sleep',
      children: [
        Text(hm(asleep), style: Theme.of(context).textTheme.displaySmall),
        Text('From ${first.hour.toString().padLeft(2, '0')}:${first.minute.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 24,
            child: Row(
              children: [
                for (final s in segments)
                  Expanded(flex: max(1, s.minutes), child: Container(color: colors[s.stage])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final st in [SleepStage.deep, SleepStage.light, SleepStage.rem, SleepStage.awake])
              if (byStage[st] != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10, color: colors[st]),
                  const SizedBox(width: 4),
                  Text('${st.name} ${hm(byStage[st]!)} (${(byStage[st]! * 100 / max(1, total)).round()}%)'),
                ]),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
    this.iconColor,
    this.trailing,
  });
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              ?trailing,
            ]),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _HourAxis extends StatelessWidget {
  const _HourAxis();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [for (final h in ['00', '06', '12', '18', '24']) Text(h, style: style)],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.values, this.color, this.grid);
  final List<int> values;
  final Color color, grid;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), Paint()..color = grid);
    final top = values.fold(0, max);
    if (top == 0) return;
    final w = size.width / values.length;
    final paint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final h = size.height * values[i] / top;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(i * w + w * 0.15, size.height - h, w * 0.7, h), const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.values != values;
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.values, this.color, this.grid);
  final List<int> values;
  final Color color, grid;

  @override
  void paint(Canvas canvas, Size size) {
    final readings = values.where((v) => v > 0);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), Paint()..color = grid);
    if (readings.isEmpty) return;
    final lo = max(0, readings.reduce(min) - 10);
    final hi = readings.reduce(max) + 10;
    final dx = size.width / values.length;
    final paint = Paint()..color = color;
    final line = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.5;
    Offset? prev;
    for (var i = 0; i < values.length; i++) {
      if (values[i] == 0) {
        prev = null;
        continue;
      }
      final p = Offset(i * dx + dx / 2, size.height - size.height * (values[i] - lo) / (hi - lo));
      if (prev != null) canvas.drawLine(prev, p, line);
      canvas.drawCircle(p, 2.5, paint);
      prev = p;
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.values != values;
}
