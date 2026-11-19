import 'package:flutter/material.dart';

import 'season.dart';

/// Design tokens per season — same names and values as the Figma
/// "Season" variable collection (one mode per season).
@immutable
class SeasonColors extends ThemeExtension<SeasonColors> {
  const SeasonColors({
    required this.canvas,
    required this.surface,
    required this.subtle,
    required this.primary,
    required this.onPrimary,
    required this.soft,
    required this.accent,
    required this.text,
    required this.muted,
    required this.border,
    this.success = const Color(0xFF3F8F5F),
    this.warning = const Color(0xFFB7802A),
    this.danger = const Color(0xFFB3423A),
    this.dangerSoft = const Color(0xFFF6DEDB),
  });

  final Color canvas, surface, subtle, primary, onPrimary, soft, accent, text, muted, border;
  final Color success, warning, danger, dangerSoft;

  static SeasonColors of(BuildContext context) => Theme.of(context).extension<SeasonColors>()!;

  static SeasonColors forSeason(Season s) => switch (s) {
        Season.grishma => const SeasonColors(
            canvas: Color(0xFFFBF6EF), surface: Colors.white, subtle: Color(0xFFF5EBDD),
            primary: Color(0xFFA9512C), onPrimary: Colors.white, soft: Color(0xFFF6DFD0),
            accent: Color(0xFFD99A2B), text: Color(0xFF2B1F17), muted: Color(0xFF7A6A5E), border: Color(0xFFEADBC9)),
        Season.barsha => const SeasonColors(
            canvas: Color(0xFFF1F5F6), surface: Colors.white, subtle: Color(0xFFE2ECEE),
            primary: Color(0xFF2F6070), onPrimary: Colors.white, soft: Color(0xFFD5E5E9),
            accent: Color(0xFF5B8C6A), text: Color(0xFF17262B), muted: Color(0xFF5D7076), border: Color(0xFFD3DFE2)),
        Season.sharat => const SeasonColors(
            canvas: Color(0xFFF4F7FB), surface: Colors.white, subtle: Color(0xFFE6EEF7),
            primary: Color(0xFF3C6E9F), onPrimary: Colors.white, soft: Color(0xFFDCE8F4),
            accent: Color(0xFFA79F7E), text: Color(0xFF1A2533), muted: Color(0xFF627082), border: Color(0xFFD9E2EC)),
        Season.hemanta => const SeasonColors(
            canvas: Color(0xFFF8F6EE), surface: Colors.white, subtle: Color(0xFFEEEADA),
            primary: Color(0xFF5F6E34), onPrimary: Colors.white, soft: Color(0xFFE4E6CE),
            accent: Color(0xFFC29A3C), text: Color(0xFF23261A), muted: Color(0xFF6E715E), border: Color(0xFFE2DECB)),
        Season.sheet => const SeasonColors(
            canvas: Color(0xFFF3F4F6), surface: Colors.white, subtle: Color(0xFFE7E9EE),
            primary: Color(0xFF4F5D75), onPrimary: Colors.white, soft: Color(0xFFDFE3EA),
            accent: Color(0xFF8E9DB5), text: Color(0xFF1D2230), muted: Color(0xFF6A7182), border: Color(0xFFDADDE4)),
        Season.basanta => const SeasonColors(
            canvas: Color(0xFFFBF5F3), surface: Colors.white, subtle: Color(0xFFF5E6E1),
            primary: Color(0xFFA9473B), onPrimary: Colors.white, soft: Color(0xFFF4DAD4),
            accent: Color(0xFF6E9B5B), text: Color(0xFF2A1C1A), muted: Color(0xFF7A6662), border: Color(0xFFEBD9D4)),
      };

  @override
  SeasonColors copyWith() => this;

  @override
  SeasonColors lerp(SeasonColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SeasonColors(
      canvas: l(canvas, other.canvas), surface: l(surface, other.surface), subtle: l(subtle, other.subtle),
      primary: l(primary, other.primary), onPrimary: l(onPrimary, other.onPrimary), soft: l(soft, other.soft),
      accent: l(accent, other.accent), text: l(text, other.text), muted: l(muted, other.muted),
      border: l(border, other.border), success: l(success, other.success), warning: l(warning, other.warning),
      danger: l(danger, other.danger), dangerSoft: l(dangerSoft, other.dangerSoft),
    );
  }
}
