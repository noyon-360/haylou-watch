import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';
import 'season.dart';

const _font = 'Manrope';
const _fallback = ['HindSiliguri']; // Bengali glyphs

/// Light, calm Material 3 theme built from one season's tokens.
ThemeData buildTheme(Season season) {
  final c = SeasonColors.forSeason(season);
  final scheme = ColorScheme(
    brightness: Brightness.light,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.soft,
    onPrimaryContainer: c.primary,
    secondary: c.accent,
    onSecondary: Colors.white,
    secondaryContainer: c.soft,
    onSecondaryContainer: c.primary,
    tertiary: c.accent,
    onTertiary: Colors.white,
    error: c.danger,
    onError: Colors.white,
    errorContainer: c.dangerSoft,
    onErrorContainer: c.danger,
    surface: c.canvas,
    onSurface: c.text,
    onSurfaceVariant: c.muted,
    surfaceContainerLowest: c.surface,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surface,
    surfaceContainerHighest: c.subtle,
    outline: c.border,
    outlineVariant: c.border,
    inverseSurface: c.text,
    onInverseSurface: c.surface,
    inversePrimary: c.soft,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: _font, fontFamilyFallback: _fallback);
  final text = base.textTheme.apply(bodyColor: c.text, displayColor: c.text, fontFamily: _font, fontFamilyFallback: _fallback);
  final shape14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const btnPad = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
  const btnText = TextStyle(fontFamily: _font, fontFamilyFallback: _fallback, fontSize: 15, fontWeight: FontWeight.w600);

  return base.copyWith(
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.canvas,
    textTheme: text,
    extensions: [c],
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: c.canvas,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.soft,
      height: 72,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? c.primary : c.muted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: _font,
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? c.primary : c.muted,
          )),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape14, padding: btnPad, textStyle: btnText, minimumSize: const Size(0, 50),
        disabledBackgroundColor: c.subtle, disabledForegroundColor: c.muted,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape14, padding: btnPad, textStyle: btnText, minimumSize: const Size(0, 50),
        foregroundColor: c.text, side: BorderSide(color: c.border), backgroundColor: c.surface,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.primary, textStyle: btnText.copyWith(fontWeight: FontWeight.w700)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected);
        if (s.contains(WidgetState.disabled)) return on ? c.primary.withValues(alpha: 0.4) : c.subtle;
        return on ? c.primary : c.subtle;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.transparent : c.border),
      thumbIcon: WidgetStateProperty.all(null),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      side: BorderSide(color: c.border, width: 2),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : Colors.transparent),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary, linearTrackColor: c.subtle, circularTrackColor: c.soft),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.text,
      contentTextStyle: TextStyle(fontFamily: _font, fontFamilyFallback: _fallback, color: c.surface, fontWeight: FontWeight.w600, fontSize: 13),
      actionTextColor: c.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.border,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: TextStyle(fontFamily: _font, fontSize: 20, fontWeight: FontWeight.w700, color: c.text),
      contentTextStyle: TextStyle(fontFamily: _font, fontSize: 14, height: 1.45, color: c.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: c.muted, fontWeight: FontWeight.w500),
      prefixIconColor: c.muted,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.primary, width: 1.5)),
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: c.surface),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
