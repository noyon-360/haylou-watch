import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/kit.dart';
import 'watch_controller.dart';

/// Figma "11 Find my phone": the watch asked this phone to ring.
class FindPhoneOverlay extends ConsumerWidget {
  const FindPhoneOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return Material(
      color: c.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PulseRings(
                      size: 240,
                      child: IconChip(
                        icon: Icons.smartphone_rounded,
                        size: 88,
                        iconSize: 40,
                        background: c.primary,
                        foreground: c.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Your watch is looking for this phone',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text)),
                    const SizedBox(height: 10),
                    Text('Playing a sound and vibrating. Tap below once you’ve found it.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.45, color: c.muted)),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: ref.read(watchControllerProvider.notifier).stopFindingPhone,
                  child: const Text('I found it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
