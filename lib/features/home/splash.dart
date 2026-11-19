import 'package:flutter/material.dart';

import '../../ui/kit.dart';
import '../../ui/logo.dart';

/// Shown while settings / permissions load (Figma "01 Splash").
class SplashView extends StatelessWidget {
  const SplashView({super.key, this.message = 'Starting secure link…'});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(size: 112),
                  const SizedBox(height: 20),
                  Text('Watch', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: c.text)),
                  const SizedBox(height: 8),
                  Text('Your watch. Your phone. Nothing else.',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.muted)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(60, 0, 60, 36),
              child: Column(
                children: [
                  const ProgressBar(height: 4),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.muted)),
                  const SizedBox(height: 10),
                  const SeasonPill(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
