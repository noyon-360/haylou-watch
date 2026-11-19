import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../theme/season.dart';
import '../../theme/theme_controller.dart';
import '../../ui/kit.dart';
import '../../ui/logo.dart';

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// Figma "15 Theme — six seasons": auto (Bengali calendar) or manual pick.
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final pref = ref.watch(themePrefProvider).value ?? const ThemePref();
    final active = ref.watch(activeSeasonProvider);
    final today = ref.watch(todayProvider);
    final calendar = ref.watch(calendarSeasonProvider);
    final notifier = ref.read(themePrefProvider.notifier);
    final next = BengaliCalendar.nextSeasonStart(today);

    return AppPage(
      title: 'Theme',
      subtitle: const SubtitleText('ষড়ঋতু · six seasons of Bangladesh'),
      onBack: () => Navigator.of(context).pop(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          GroupCard(children: [
            SwitchRow(
              title: 'Follow the seasons',
              subtitle: 'Changes automatically with the Bengali calendar (বঙ্গাব্দ)',
              value: pref.auto,
              onChanged: notifier.setAuto,
            ),
          ]),
          const SizedBox(height: 14),
          SurfaceCard(
            color: c.soft,
            borderColor: c.soft,
            child: Row(
              children: [
                const AppLogo(size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pref.auto ? 'এখন ${calendar.bn} · Now ${calendar.en}' : 'Showing ${active.en} · ${active.bn}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.primary)),
                      const SizedBox(height: 4),
                      Text(
                        pref.auto
                            ? '${calendar.monthsEn}. Switches to ${calendar.next.en} (${calendar.next.english.toLowerCase()}) on ${next.day} ${_months[next.month - 1]}.'
                            : 'Picked by you. By the calendar it is ${calendar.en} (${calendar.bn}) — turn on “Follow the seasons” to switch automatically.',
                        style: TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w500, color: c.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SectionLabel(pref.auto ? 'Or pick one' : 'Pick a season'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.18,
            children: [
              for (final s in Season.values)
                _SeasonTile(
                  season: s,
                  selected: s == active,
                  isToday: s == calendar,
                  onTap: () => notifier.pick(s),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('The app icon and status notification change colour with the theme. Light, calm palettes only.',
              style: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w500, color: c.muted)),
        ],
      ),
    );
  }
}

/// A tile rendered in its own season's theme, so it previews the palette.
class _SeasonTile extends StatelessWidget {
  const _SeasonTile({required this.season, required this.selected, required this.isToday, required this.onTap});
  final Season season;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(season),
      child: Builder(builder: (context) {
        final c = SeasonColors.of(context);
        return Material(
          color: c.canvas,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: selected ? c.primary : c.border, width: selected ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(child: ColoredBox(color: c.primary, child: Center(child: KeyholeGlyph(size: 34, color: c.onPrimary)))),
                        Expanded(child: ColoredBox(color: c.accent)),
                        Expanded(child: ColoredBox(color: c.soft)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(season.icon, size: 18, color: c.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(season.en, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
                            Text(isToday ? '${season.bn} · now' : season.bn,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
                          ],
                        ),
                      ),
                      if (selected)
                        IconChip(icon: Icons.check_rounded, size: 22, iconSize: 14, background: c.primary, foreground: c.onPrimary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
