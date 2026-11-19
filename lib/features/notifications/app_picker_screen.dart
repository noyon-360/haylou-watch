import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_settings.dart';
import '../../platform/native_bridge.dart';
import '../../ui/kit.dart';
import 'alert_providers.dart';
import 'app_types.dart';

enum _Filter { all, selected, messaging }

/// Figma "16b Alerts — choose apps". Every tick is saved immediately
/// (AppSettingsNotifier); "Done" just closes the screen.
class AppPickerScreen extends ConsumerStatefulWidget {
  const AppPickerScreen({super.key});

  @override
  ConsumerState<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends ConsumerState<AppPickerScreen> {
  // Local view state only.
  String _query = '';
  _Filter _filter = _Filter.all;

  /// Apps selected when the screen opened stay in the "Selected" section even
  /// if unticked, so rows don't jump around while the user is editing.
  late final Set<String> _pinned = {...?ref.read(appSettingsProvider).value?.allowedApps};

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = ref.watch(listenerEnabledProvider).value ?? false;
    final selected = ref.watch(appSettingsProvider.select((s) => s.value?.allowedApps ?? const <String>{}));
    final apps = ref.watch(installedAppsProvider);
    final store = ref.read(appSettingsProvider.notifier);
    final all = apps.value ?? const <InstalledApp>[];

    bool matches(InstalledApp a) =>
        _query.isEmpty || a.label.toLowerCase().contains(_query) || a.package.toLowerCase().contains(_query);
    final visible = all.where(matches).where((a) => switch (_filter) {
          _Filter.all => true,
          _Filter.selected => selected.contains(a.package),
          _Filter.messaging => isMessagingApp(a.package),
        });
    final top = _filter == _Filter.all ? visible.where((a) => _pinned.contains(a.package)).toList() : const <InstalledApp>[];
    final rest = _filter == _Filter.all ? visible.where((a) => !_pinned.contains(a.package)).toList() : visible.toList();

    Widget chip(String label, _Filter f) {
      final on = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: on ? c.primary : c.surface,
          shape: StadiumBorder(side: BorderSide(color: on ? c.primary : c.border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => setState(() => _filter = f),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? c.onPrimary : c.text)),
            ),
          ),
        ),
      );
    }

    Widget section(String title, List<InstalledApp> list) => SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverMainAxisGroup(slivers: [
            SliverToBoxAdapter(child: SectionLabel(title)),
            DecoratedSliver(
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.border)),
              sliver: SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: c.border),
                itemBuilder: (_, i) {
                  final app = list[i];
                  return _PickRow(
                    app: app,
                    selected: selected.contains(app.package),
                    enabled: enabled,
                    onChanged: (v) => store.setAppForwarded(app.package, v),
                  );
                },
              ),
            ),
          ]),
        );

    return AppPage(
      title: 'Choose apps',
      subtitle: const SubtitleText('Ticked apps can send alerts to the watch'),
      onBack: () => Navigator.of(context).pop(),
      bottom: _BottomBar(count: selected.length),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverList.list(children: [
              if (!enabled) ...[const ListenerStatusCard(), const SizedBox(height: 10)],
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: apps.hasValue ? 'Search ${all.length} apps' : 'Search apps',
                ),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  chip('All', _Filter.all),
                  chip('Selected · ${selected.length}', _Filter.selected),
                  chip('Messaging', _Filter.messaging),
                ]),
              ),
            ]),
          ),
          if (apps.isLoading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList.list(children: [
                for (var i = 0; i < 6; i++)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [Skeleton(width: 36, height: 36, radius: 12), SizedBox(width: 12), Expanded(child: Skeleton(height: 14))]),
                  ),
              ]),
            )
          else if (top.isEmpty && rest.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    _filter == _Filter.selected && _query.isEmpty ? 'No apps selected yet' : 'No apps match',
                    style: TextStyle(fontSize: 14, color: c.muted),
                  ),
                ),
              ),
            )
          else ...[
            if (top.isNotEmpty) section('Selected', top),
            if (rest.isNotEmpty)
              section(
                switch (_filter) {
                  _Filter.all => 'All apps · A–Z',
                  _Filter.selected => 'Selected · ${rest.length}',
                  _Filter.messaging => 'Messaging apps · ${rest.length}',
                },
                rest,
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ],
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({required this.app, required this.selected, required this.enabled, required this.onChanged});
  final InstalledApp app;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: enabled ? () => onChanged(!selected) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        child: Row(children: [
          AppAvatar(label: app.label, package: app.package, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
              Text(app.package,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: c.muted)),
            ]),
          ),
          Checkbox(value: selected, onChanged: enabled ? (v) => onChanged(v ?? false) : null),
        ]),
      ),
    );
  }
}

/// Sticky "4 apps selected · Saved instantly  [Done]".
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      padding: EdgeInsets.fromLTRB(20, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$count ${count == 1 ? 'app' : 'apps'} selected', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
            Text('Saved instantly', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted)),
          ]),
        ),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ]),
    );
  }
}
