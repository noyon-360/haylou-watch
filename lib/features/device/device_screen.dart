import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_settings.dart';
import '../../data/health_store.dart';
import '../../data/saved_device.dart';
import '../../protocol/history.dart';
import '../../theme/palette.dart';
import '../../ui/kit.dart';
import '../debug/console_screen.dart';
import '../home/home_shell.dart';
import '../settings/theme_screen.dart';
import 'watch_controller.dart';

/// Watch tab (Figma 07–12): one screen, every connection & sync state.
class DeviceScreen extends ConsumerWidget {
  const DeviceScreen({super.key, required this.device});
  final SavedDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ref.watch(watchControllerProvider);
    final controller = ref.read(watchControllerProvider.notifier);

    // Side effect: confirm a finished sync with a toast (once per sync).
    ref.listen(watchControllerProvider.select((w) => w.lastSync), (prev, next) {
      final summary = ref.read(watchControllerProvider).lastSyncSummary;
      if (next == null || prev == next || summary == null) return;
      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          persist: false, // auto-hide even though it has an action
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: context.c.success, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(summary)),
            ],
          ),
          action: SnackBarAction(label: 'View', onPressed: () => ref.read(homeTabProvider.notifier).select(1)),
        ),
      );
    });

    final connecting = watch.isBusy || (watch.isReady && !watch.infoLoaded);
    final reconnecting = !connecting && !watch.isReady && watch.retryAt != null;

    return AppPage(
      title: device.name,
      subtitle: Align(
        alignment: Alignment.centerLeft,
        child: SeasonPill(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ThemeScreen()))),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: context.c.text),
          onSelected: (v) {
            if (v == 'forget') confirmForget(context, ref);
            if (v == 'console') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsoleScreen()));
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'console', child: Text('Debug console')),
            PopupMenuItem(value: 'forget', child: Text('Forget this watch')),
          ],
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: connecting
                ? _ConnectingCard(key: const ValueKey('connecting'), state: watch, deviceId: device.id)
                : _HeroCard(
                    key: const ValueKey('hero'),
                    state: watch,
                    reconnecting: reconnecting,
                    onConnect: () => controller.connect(device.id),
                    onReconnect: controller.reconnectNow,
                  ),
          ),
          if (watch.syncing) ...[const SizedBox(height: 14), _SyncCard(state: watch)],
          const SizedBox(height: 14),
          _Actions(state: watch),
          const SizedBox(height: 6),
          _TodayStats(state: watch, loading: connecting),
          const SizedBox(height: 14),
          const _PrivacyLine(),
        ],
      ),
    );
  }
}

/// Shared with Settings → "Forget this watch".
Future<void> confirmForget(BuildContext context, WidgetRef ref) async {
  final c = context.c;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: IconChip(icon: Icons.watch_off_outlined, size: 48, iconSize: 24, background: c.dangerSoft, foreground: c.danger),
      title: const Text('Forget this watch?'),
      content: const Text('The app disconnects and you can pair again from the scan screen. Health data on this phone is kept.'),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.dangerSoft, foregroundColor: c.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Forget'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await ref.read(watchControllerProvider.notifier).forget();
  ref.invalidate(homeTabProvider);
  await ref.read(savedDeviceProvider.notifier).clear();
}

// ---------------------------------------------------------------------------

class _ConnectingCard extends StatelessWidget {
  const _ConnectingCard({super.key, required this.state, required this.deviceId});
  final WatchState state;
  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Order of the connection pipeline (see WatchController.connect).
    final stage = switch (state.status) {
      LinkStatus.connecting => 0,
      LinkStatus.discovering => 1,
      LinkStatus.handshaking => 2,
      LinkStatus.ready => state.infoLoaded ? 4 : 3,
      _ => 0,
    };
    StepStatus st(int i) => i < stage ? StepStatus.done : (i == stage ? StepStatus.active : StepStatus.todo);
    final mtu = state.mtu == null ? '' : ' · MTU ${state.mtu}';

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Connecting to your watch',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text),
                ),
              ),
              Text(
                '${min(stage + 1, 4)} / 4',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(value: (stage + 0.5) / 4),
          const SizedBox(height: 8),
          StepItem(state: st(0), title: 'Bluetooth link', subtitle: stage > 0 ? '$deviceId$mtu' : 'Reaching $deviceId…'),
          StepItem(state: st(1), title: 'Watch services found', subtitle: stage == 1 ? 'Discovering…' : null),
          StepItem(state: st(2), title: 'Secure handshake', subtitle: stage == 2 ? 'Waiting for the watch…' : null),
          StepItem(state: st(3), title: 'Read battery & set time', subtitle: stage == 3 ? 'Almost there…' : null),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({super.key, required this.state, required this.reconnecting, required this.onConnect, required this.onReconnect});
  final WatchState state;
  final bool reconnecting;
  final VoidCallback onConnect;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ready = state.isReady;
    final b = state.battery;

    final Widget statusLead;
    final String statusText;
    final Color statusColor;
    if (ready) {
      (statusLead, statusText, statusColor) = (Dot(c.success), 'Connected', c.success);
    } else if (reconnecting) {
      (statusLead, statusText, statusColor) = (const ArcSpinner(size: 14, stroke: 2), 'Reconnecting…', c.warning);
    } else if (state.status == LinkStatus.error) {
      (statusLead, statusText, statusColor) = (Dot(c.danger), 'Connection failed', c.danger);
    } else {
      (statusLead, statusText, statusColor) = (Dot(c.muted), 'Disconnected', c.muted);
    }

    final Widget sub;
    if (ready) {
      final sync = state.syncing ? 'Syncing now' : 'Last sync ${state.lastSync == null ? '—' : hhmm(state.lastSync!)}';
      sub = Text('Battery · $sync${state.serial == null ? '' : ' · ${state.serial}'}', style: _subStyle(c));
    } else if (reconnecting) {
      sub = _Countdown(state: state);
    } else {
      final text = state.status == LinkStatus.error && state.message != null ? state.message! : 'Tap Connect to link your watch';
      sub = Text(text, style: _subStyle(c), maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        children: [
          Row(
            children: [
              BatteryRing(value: b == null ? null : b / 100, dim: !ready),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        statusLead,
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b == null ? '--%' : '$b%',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ready ? c.text : c.muted),
                    ),
                    sub,
                  ],
                ),
              ),
            ],
          ),
          if (reconnecting) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
              child: Text(
                'Bring the watch closer, and make sure the official Haylou app isn’t connected to it.',
                style: TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w500, color: c.text),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(onPressed: onReconnect, child: const Text('Reconnect now')),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsoleScreen())),
                  child: const Text('Details'),
                ),
              ],
            ),
          ] else if (!ready) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: onConnect, child: const Text('Connect')),
            ),
          ],
        ],
      ),
    );
  }

  static TextStyle _subStyle(SeasonColors c) => TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted, height: 1.35);
}

/// "Last seen 2 min ago · retrying in 8 s (attempt 3)", ticking every second.
class _Countdown extends StatefulWidget {
  const _Countdown({required this.state});
  final WatchState state;
  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final left = s.retryAt == null ? 0 : max(0, s.retryAt!.difference(DateTime.now()).inSeconds);
    final seen = s.lastSeen == null ? '' : 'Last seen ${agoText(s.lastSeen!)} · ';
    final when = left == 0 ? 'retrying now' : 'retrying in $left s';
    return Text(
      '$seen$when (attempt ${s.attempt})',
      style: TextStyle(fontSize: 12, height: 1.35, fontWeight: FontWeight.w500, color: context.c.muted),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.state});
  final WatchState state;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final step = state.syncStep ?? 0;
    StepStatus st(int i) => i < step ? StepStatus.done : (i == step ? StepStatus.active : StepStatus.todo);
    final pct = ((step + 0.5) / 3 * 100).round();
    const titles = ['Steps', 'Heart rate', 'Sleep'];
    const active = ['Reading hourly steps…', 'Reading heart rate…', 'Reading sleep…'];

    return SurfaceCard(
      borderColor: c.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ArcSpinner(size: 20, stroke: 2.6),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Syncing health data',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text),
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(value: pct / 100),
          const SizedBox(height: 8),
          for (var i = 0; i < 3; i++)
            StepItem(state: st(i), title: titles[i], subtitle: state.syncNotes[i] ?? (i == step ? active[i] : 'Waiting')),
          const SizedBox(height: 4),
          Text(
            'You can leave this screen — sync continues in the background.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted),
          ),
        ],
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.state});
  final WatchState state;

  Future<void> _guard(BuildContext context, Future<void> Function() op, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await op();
      if (done.isNotEmpty) messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(watchControllerProvider.notifier);
    final ready = state.isReady;
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.vibration_rounded,
            label: 'Find watch',
            onTap: ready ? () => _guard(context, controller.findWatch, 'Watch is vibrating') : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.sync_rounded,
            label: state.syncing ? 'Syncing…' : 'Sync now',
            busy: state.syncing,
            onTap: ready && !state.syncing ? () => _guard(context, controller.syncHealth, '') : null,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, this.onTap, this.busy = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = onTap != null;
    return Material(
      color: on ? c.soft : c.subtle,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              busy ? const ArcSpinner(size: 20, stroke: 2.4) : Icon(icon, size: 20, color: on ? c.primary : c.muted),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: on ? c.primary : c.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayStats extends ConsumerWidget {
  const _TodayStats({required this.state, required this.loading});
  final WatchState state;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final health = ref.watch(healthStoreProvider);
    final goal = ref.watch(appSettingsProvider.select((s) => s.value?.params.stepGoal ?? 8000));
    final day = health.value?[dayKey(DateTime.now())];
    final stale = !state.isReady;
    final skeleton = loading && day == null;

    final steps = day?.steps ?? 0;
    final readings = day?.heartReadings ?? const <int>[];
    final live = state.liveHeart;
    final heart = live ?? (readings.isEmpty ? null : readings.last);
    final asleep = (day?.sleep ?? const <SleepSegment>[]).where((s) => s.stage != SleepStage.awake).fold(0, (a, s) => a + s.minutes);

    final when = skeleton
        ? 'Loading…'
        : stale
        ? (state.lastSync == null ? 'Last known' : 'Last known · ${hhmm(state.lastSync!)}')
        : (state.lastSync == null ? 'Not synced yet' : 'Updated ${hhmm(state.lastSync!)}');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Today',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text),
                ),
              ),
              Text(
                when,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted),
              ),
            ],
          ),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.directions_walk_rounded,
                  label: 'Steps',
                  value: _thousands(steps),
                  unit: '/ ${goal >= 1000 ? '${(goal / 1000).toStringAsFixed(goal % 1000 == 0 ? 0 : 1)}k' : goal}',
                  progress: min(1, steps / max(1, goal)),
                  stale: stale,
                  skeleton: skeleton,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.favorite_border_rounded,
                  label: 'Heart',
                  value: heart == null ? '--' : '$heart',
                  unit: 'bpm',
                  liveLabel: live != null && !stale ? 'live' : (heart == null ? 'no data' : 'last'),
                  liveColor: live != null && !stale ? c.danger : c.muted,
                  stale: stale,
                  skeleton: skeleton,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.bedtime_outlined,
                  label: 'Sleep',
                  value: asleep == 0 ? '--' : '${asleep ~/ 60}h ${asleep % 60}m',
                  progress: asleep == 0 ? null : min(1, asleep / 480),
                  liveLabel: 'no data',
                  stale: stale,
                  skeleton: skeleton,
                ),
              ),
            ],
          ),
        ),
      ],
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.progress,
    this.liveLabel,
    this.liveColor,
    this.stale = false,
    this.skeleton = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final double? progress;
  final String? liveLabel;
  final Color? liveColor;
  final bool stale;
  final bool skeleton;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SurfaceCard(
      radius: 18,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: c.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (skeleton) ...[
            const Skeleton(width: 64, height: 20),
            const SizedBox(height: 8),
            const Skeleton(width: 40, height: 8, radius: 4),
          ] else ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: stale ? c.muted : c.text),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 3),
                    Text(
                      unit!,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (progress != null)
              ProgressBar(value: progress, height: 4, color: stale ? c.muted : null)
            else
              Row(
                children: [
                  Dot(liveColor ?? c.muted, size: 6),
                  const SizedBox(width: 4),
                  Text(
                    liveLabel ?? '',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Icon(Icons.lock_outline_rounded, size: 16, color: c.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Everything stays on this phone — no account, no internet.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted),
          ),
        ),
      ],
    );
  }
}
