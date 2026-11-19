import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_runtime.dart';
import 'features/home/home_router.dart';
import 'features/permission/permission_gate.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // One container for the whole process. The Android side keeps this engine
  // alive (cached engine + foreground service), so the runtime keeps the watch
  // connected and forwards notifications even with no screen open.
  final container = ProviderContainer();
  container.read(appRuntimeProvider);
  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The whole UI (colours + logo) follows the active season.
    final season = ref.watch(activeSeasonProvider);
    return MaterialApp(
      title: 'Watch',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(season),
      themeMode: ThemeMode.light,
      themeAnimationDuration: const Duration(milliseconds: 450),
      home: const PermissionGate(child: HomeRouter()),
    );
  }
}
