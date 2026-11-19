import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_runtime.dart';
import 'features/home/home_router.dart';
import 'features/permission/permission_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // One container for the whole process. The Android side keeps this engine
  // alive (cached engine + foreground service), so the runtime keeps the watch
  // connected and forwards notifications even with no screen open.
  final container = ProviderContainer();
  container.read(appRuntimeProvider);
  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Watch',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
      darkTheme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
      ),
      home: const PermissionGate(child: HomeRouter()),
    );
  }
}
