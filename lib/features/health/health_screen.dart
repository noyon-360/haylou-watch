import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_settings.dart';
import '../../data/health_store.dart';
import '../../protocol/history.dart';
import '../../theme/palette.dart';
import '../../ui/kit.dart';
import '../device/watch_controller.dart';

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// Figma "13 Health — today".
class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  int _daysAgo = 0; // purely local view state

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(healthStoreProvider);
    final days = health.value ?? const {};
    final settings = ref.watch(appSettingsProvider).value ?? const AppSettings();
    final watch = ref.watch(watchControllerProvider);
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: _daysAgo));
    final day = days[dayKey(date)];
    final loading = day == null && (health.isLoading || watch.syncing);

    final title = switch (_daysAgo) { 0 => 'Today', 1 => 'Yesterday', _ => _weekdays[date.weekday - 1] };
    final sub = watch.syncing
        ? 'Syncing from the watch…'
        : watch.lastSync == null
            ? 'Not synced yet · stored on this phone'
            : 'Synced ${hhmm(watch.lastSync!)} · stored on this phone';

    return AppPage(
      title: 'Health',
      subtitle: SubtitleText(sub),
      actions: [
        ChipIconButton(
          icon: Icons.sync_rounded,
          tooltip: 'Sync from watch',
          busy: watch.syncing,
          onPressed: watch.isReady ? () => ref.read(watchControllerProvider.notifier).syncHealth() : null,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _DateSwitcher(
            title: title,
            subtitle: _daysAgo < 2
                ? '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}'
                : '${date.day} ${_months[date.month - 1]} ${date.year}',
            onPrev: _daysAgo < 29 ? () => setState(() => _daysAgo++) : null,
            onNext: _daysAgo > 0 ? () => setState(() => _daysAgo--) : null,
          ),
          const SizedBox(height: 14),
          _StepsCard(day: day, settings: settings, loading: loading),
          const SizedBox(height: 14),
          _HeartCard(day: day, live: _daysAgo == 0 && watch.isReady ? watch.liveHeart : null, loading: loading),
          const SizedBox(height: 14),
          _SleepCard(segments: day?.sleep ?? const [], loading: loading),
        ],
      ),
    );
  }
}

class _DateSwitcher extends StatelessWidget {
  const _DateSwitcher({required this.title, required this.subtitle, this.onPrev, this.onNext});
  final String title, subtitle;
  final VoidCallback? onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget btn(IconData i, VoidCallback? f) => Material(
          color: c.subtle,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: f,
            child: SizedBox.square(dimension: 34, child: Icon(i, size: 20, color: f == null ? c.border : c.text)),
          ),
        );
    return SurfaceCard(
      radius: 16,
      padding: const EdgeInsets.all(6),
      child: Row(children: [
        btn(Icons.chevron_left_rounded, onPrev),
        Expanded(
          child: Column(children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
            Text(subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted)),
          ]),
        ),
        btn(Icons.chevron_right_rounded, onNext),
      ]),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(children: [
      Icon(icon, size: 18, color: c.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text))),
      ?trailing,
    ]);
  }
}

class _BigNumber extends StatelessWidget {
  const _BigNumber(this.value, {this.suffix});
  final String value;
  final String? suffix;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
      Text(value, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: c.text, height: 1.15)),
      if (suffix != null) ...[
        const SizedBox(width: 6),
        Text(suffix!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.muted)),
      ],
    ]);
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.c.muted)),
      );
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();
  @override
  Widget build(BuildContext context) => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Skeleton(width: 120, height: 30),
        SizedBox(height: 12),
        Skeleton(height: 8, radius: 4),
        SizedBox(height: 12),
        Skeleton(height: 64, radius: 10),
      ]);
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.day, required this.settings, required this.loading});
  final DayHealth? day;
  final AppSettings settings;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = settings.params;
    final steps = day?.steps ?? 0;
    final goal = max(1, p.stepGoal);
    // Estimates: stride ≈ 0.415 × height; energy ≈ 0.5 kcal per kg per km walked.
    final km = steps * p.heightCm * 0.415 / 100000;
    final kcal = km * p.weightKg * 0.5;
    final dist = settings.metric ? '${km.toStringAsFixed(1)} km' : '${(km * 0.621).toStringAsFixed(1)} mi';
    final pct = (steps * 100 / goal).round();

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.directions_walk_rounded,
            title: 'Steps',
            trailing: Text('$pct% of goal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.primary)),
          ),
          const SizedBox(height: 12),
          if (loading)
            const _LoadingBody()
          else ...[
            _BigNumber(_thousands(steps), suffix: '/ ${_thousands(goal)}'),
            const SizedBox(height: 10),
            ProgressBar(value: min(1, steps / goal), height: 8),
            const SizedBox(height: 10),
            Text('$dist  ·  ${kcal.round()} kcal  ·  ${day?.activeMinutes ?? 0} active min',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.muted)),
            const SizedBox(height: 14),
            SizedBox(
              height: 72,
              child: CustomPaint(size: Size.infinite, painter: _BarsPainter(day?.hourlySteps ?? List.filled(24, 0), c)),
            ),
            const SizedBox(height: 6),
            const _HourAxis(),
          ],
        ],
      ),
    );
  }
}

class _HeartCard extends StatelessWidget {
  const _HeartCard({required this.day, this.live, required this.loading});
  final DayHealth? day;
  final int? live;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = day?.heartReadings ?? const <int>[];
    Widget stat(String k, String v) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: c.canvas, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted)),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(width: 3),
                Text('bpm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted)),
              ]),
            ]),
          ),
        );

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.favorite_border_rounded,
            title: 'Heart rate',
            trailing: live == null
                ? null
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: c.dangerSoft, borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Dot(c.danger, size: 6),
                      const SizedBox(width: 6),
                      Text('Live $live bpm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.danger)),
                    ]),
                  ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const _LoadingBody()
          else if (r.isEmpty)
            const _Empty('No heart-rate readings for this day.')
          else ...[
            Row(children: [
              stat('Average', '${(r.reduce((a, b) => a + b) / r.length).round()}'),
              const SizedBox(width: 10),
              stat('Lowest', '${r.reduce(min)}'),
              const SizedBox(width: 10),
              stat('Highest', '${r.reduce(max)}'),
            ]),
            const SizedBox(height: 14),
            SizedBox(height: 84, child: CustomPaint(size: Size.infinite, painter: _LinePainter(day!.heart, c))),
            const SizedBox(height: 6),
            const _HourAxis(),
          ],
        ],
      ),
    );
  }
}

class _SleepCard extends StatelessWidget {
  const _SleepCard({required this.segments, required this.loading});
  final List<SleepSegment> segments;
  final bool loading;

  static Color colorFor(SleepStage s, SeasonColors c) => switch (s) {
        SleepStage.deep => c.primary,
        SleepStage.light => c.primary.withValues(alpha: 0.45),
        SleepStage.rem => c.accent,
        SleepStage.awake => c.border,
        SleepStage.unknown => c.subtle,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    String hm(int m) => '${m ~/ 60}h ${m % 60}m';
    String t(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

    if (loading || segments.isEmpty) {
      return SurfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _CardHeader(icon: Icons.bedtime_outlined, title: 'Sleep'),
          const SizedBox(height: 12),
          loading ? const _LoadingBody() : const _Empty('No sleep recorded for this night.'),
        ]),
      );
    }

    final byStage = <SleepStage, int>{};
    for (final s in segments) {
      byStage[s.stage] = (byStage[s.stage] ?? 0) + s.minutes;
    }
    final asleep = segments.where((s) => s.stage != SleepStage.awake).fold(0, (a, s) => a + s.minutes);
    final first = segments.first, last = segments.last;
    final endMin = last.hour * 60 + last.minute + last.minutes;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.bedtime_outlined,
            title: 'Sleep',
            trailing: Text('${t(first.hour, first.minute)} → ${t((endMin ~/ 60) % 24, endMin % 60)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
          ),
          const SizedBox(height: 12),
          _BigNumber(hm(asleep)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 18,
              child: Row(children: [
                for (final s in segments) Expanded(flex: max(1, s.minutes), child: ColoredBox(color: colorFor(s.stage, c))),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final (st, name) in [(SleepStage.deep, 'Deep'), (SleepStage.light, 'Light'), (SleepStage.rem, 'REM'), (SleepStage.awake, 'Awake')])
                if (byStage[st] != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Dot(colorFor(st, c)),
                    const SizedBox(width: 6),
                    Text('$name ${hm(byStage[st]!)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
                  ]),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourAxis extends StatelessWidget {
  const _HourAxis();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: context.c.muted);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [for (final h in ['00', '06', '12', '18', '24']) Text(h, style: style)],
    );
  }
}

String _thousands(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Hourly step bars; the busiest hour is full colour, others softer.
class _BarsPainter extends CustomPainter {
  _BarsPainter(this.values, this.c);
  final List<int> values;
  final SeasonColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final top = values.fold(0, max);
    final w = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final h = top == 0 || v == 0 ? 3.0 : max(3.0, size.height * v / top);
      final color = v == 0 ? c.subtle : (v == top ? c.primary : c.primary.withValues(alpha: 0.55));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(i * w + w * 0.18, size.height - h, w * 0.64, h), const Radius.circular(3)),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.values != values || old.c != c;
}

/// Heart rate across the day (144 ten-minute slots); gaps break the line.
class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.c);
  final List<int> values;
  final SeasonColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final readings = values.where((v) => v > 0);
    if (readings.isEmpty) return;
    final lo = max(0, readings.reduce(min) - 8);
    final hi = readings.reduce(max) + 8;
    final dx = size.width / (values.length - 1);
    double y(int v) => size.height - size.height * (v - lo) / (hi - lo);

    final line = Paint()
      ..color = c.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path();
    var open = false;
    var lastGap = 0;
    for (var i = 0; i < values.length; i++) {
      if (values[i] == 0) {
        if (++lastGap > 3) open = false; // break after 40 min without data
        continue;
      }
      lastGap = 0;
      final p = Offset(i * dx, y(values[i]));
      if (open) {
        path.lineTo(p.dx, p.dy);
      } else {
        path.moveTo(p.dx, p.dy);
        canvas.drawCircle(p, 1.6, Paint()..color = c.primary);
        open = true;
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values || old.c != c;
}
