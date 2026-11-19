import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/palette.dart';
import '../theme/theme_controller.dart';

/// Shared building blocks matching the Figma "App UI" components.

extension Ctx on BuildContext {
  SeasonColors get c => SeasonColors.of(this);
}

/// Page scaffold: custom top bar + body on the season canvas.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.bottom,
  });
  final String title;
  final Widget? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final Widget body;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(onBack != null ? 6 : 20, 10, 12, 8),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded), color: c.text),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: onBack != null ? 20 : 24, fontWeight: FontWeight.w700, color: c.text)),
                        if (subtitle != null) ...[const SizedBox(height: 4), subtitle!],
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            Expanded(child: body),
            ?bottom,
          ],
        ),
      ),
    );
  }
}

class SubtitleText extends StatelessWidget {
  const SubtitleText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: context.c.muted));
}

/// Round icon button on a surface chip (top-bar actions).
class ChipIconButton extends StatelessWidget {
  const ChipIconButton({super.key, required this.icon, this.onPressed, this.tooltip, this.busy = false});
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: c.surface,
        shape: CircleBorder(side: BorderSide(color: c.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onPressed,
          child: Tooltip(
            message: tooltip ?? '',
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: busy
                    ? const ArcSpinner(size: 18, stroke: 2.4)
                    : Icon(icon, size: 20, color: onPressed == null ? c.muted : c.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White card with a hairline border.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.borderColor, this.radius = 20});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.border),
      ),
      child: child,
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(text.toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: context.c.muted)),
            ),
            ?trailing,
          ],
        ),
      );
}

/// Grouped rows inside one card, separated by hairlines.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Divider(height: 1, color: context.c.border));
      items.add(children[i]);
    }
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ClipRRect(borderRadius: BorderRadius.circular(19), child: Column(children: items)),
    );
  }
}

class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.title, this.subtitle, required this.value, this.onChanged});
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = onChanged != null;
    return InkWell(
      onTap: enabled ? () => onChanged!(!value) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: enabled ? c.text : c.muted)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: TextStyle(fontSize: 13, color: c.muted, height: 1.35)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class ValueRow extends StatelessWidget {
  const ValueRow({super.key, required this.title, this.value, this.subtitle, this.leading, this.onTap, this.danger = false});
  final String title;
  final String? value;
  final Widget? subtitle;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500, color: danger ? c.danger : (onTap == null ? c.muted : c.text))),
                  if (subtitle != null) ...[const SizedBox(height: 2), subtitle!],
                ],
              ),
            ),
            if (value != null) Text(value!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.muted)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: c.muted),
          ],
        ),
      ),
    );
  }
}

class IconChip extends StatelessWidget {
  const IconChip({super.key, required this.icon, this.size = 40, this.background, this.foreground, this.iconSize});
  final IconData icon;
  final double size;
  final Color? background;
  final Color? foreground;
  final double? iconSize;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        decoration: BoxDecoration(color: background ?? context.c.soft, shape: BoxShape.circle),
        child: Icon(icon, size: iconSize ?? size * 0.5, color: foreground ?? context.c.primary),
      );
}

/// "হেমন্ত · Hemanta" chip for the active season.
class SeasonPill extends ConsumerWidget {
  const SeasonPill({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(activeSeasonProvider);
    final c = context.c;
    return Material(
      color: c.soft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 4, 12, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(s.icon, size: 14, color: c.primary),
              const SizedBox(width: 6),
              Text('${s.bn} · ${s.en}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = 8});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Rounded progress bar; null value = indeterminate.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, this.value, this.height = 6, this.color});
  final double? value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (value == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(minHeight: height, color: color ?? c.primary, backgroundColor: c.subtle),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value!.clamp(0, 1)),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          color: color ?? c.primary,
          backgroundColor: c.subtle,
        ),
      ),
    );
  }
}

/// Small circular spinner on a soft track (Figma "spinner").
class ArcSpinner extends StatelessWidget {
  const ArcSpinner({super.key, this.size = 26, this.stroke = 3});
  final double size;
  final double stroke;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: stroke, color: context.c.primary, backgroundColor: context.c.soft, strokeCap: StrokeCap.round),
      );
}

/// Shimmering placeholder block while data loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 6});
  final double? width;
  final double height;
  final double radius;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value * 3 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [c.subtle, Color.lerp(c.subtle, c.surface, 0.7)!, c.subtle],
            ),
          ),
        );
      },
    );
  }
}

enum StepStatus { done, active, todo, failed }

/// One line of a progress checklist (connecting / syncing).
class StepItem extends StatelessWidget {
  const StepItem({super.key, required this.state, required this.title, this.subtitle});
  final StepStatus state;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lead = switch (state) {
      StepStatus.done => IconChip(icon: Icons.check_rounded, size: 26, background: c.primary, foreground: c.onPrimary, iconSize: 16),
      StepStatus.active => const ArcSpinner(size: 26),
      StepStatus.failed => IconChip(icon: Icons.close_rounded, size: 26, background: c.dangerSoft, foreground: c.danger, iconSize: 16),
      StepStatus.todo => Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.border, width: 2)),
        ),
    };
    final muted = state == StepStatus.todo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(state), child: lead)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: muted ? FontWeight.w500 : FontWeight.w700, color: muted ? c.muted : c.text)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: state == StepStatus.active ? c.primary : (state == StepStatus.failed ? c.danger : c.muted))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Expanding pulse rings around [child] (scan radar, find-my-phone).
class PulseRings extends StatefulWidget {
  const PulseRings({super.key, required this.size, required this.child, this.animate = true});
  final double size;
  final Widget child;
  final bool animate;
  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(PulseRings old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ctrl.isAnimating) _ctrl.repeat();
    if (!widget.animate) _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.c.primary;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => CustomPaint(painter: _RingsPainter(_ctrl.value, color, widget.animate), child: child),
        child: Center(child: widget.child),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.t, this.color, this.animate);
  final double t;
  final Color color;
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.width / 2;
    // Static rings (as in Figma) + one expanding wave.
    for (final (r, a) in [(1.0, 0.10), (0.73, 0.16), (0.47, 0.28)]) {
      canvas.drawCircle(center, maxR * r, Paint()..color = color.withValues(alpha: a));
    }
    if (animate) {
      final r = maxR * (0.4 + 0.6 * t);
      canvas.drawCircle(center, r, Paint()..color = color.withValues(alpha: 0.18 * (1 - t)));
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.t != t || old.color != color;
}

class SignalBars extends StatelessWidget {
  const SignalBars(this.rssi, {super.key});
  final int rssi;

  int get bars => rssi >= -60 ? 4 : rssi >= -70 ? 3 : rssi >= -80 ? 2 : 1;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            margin: const EdgeInsets.only(left: 2),
            width: 4,
            height: 5.0 + i * 3,
            decoration: BoxDecoration(color: i < bars ? c.primary : c.border, borderRadius: BorderRadius.circular(1)),
          ),
      ],
    );
  }
}

/// Battery ring around the watch icon.
class BatteryRing extends StatelessWidget {
  const BatteryRing({super.key, required this.value, this.size = 72, this.dim = false});
  final double? value; // 0..1
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value ?? 0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => CustomPaint(
          painter: _RingPainter(v, dim ? c.muted : (value != null && value! <= 0.2 ? c.danger : c.primary), c.subtle),
          child: child,
        ),
        child: Center(child: Icon(Icons.watch_outlined, size: size * 0.42, color: dim ? c.muted : c.primary)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.track);
  final double v;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 5.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(w / 2);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = w);
    if (v > 0) {
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.color != color;
}

String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String agoText(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}
