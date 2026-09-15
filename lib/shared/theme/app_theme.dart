import 'package:flutter/material.dart';

/// CoreGrid's brand palette, sourced from `assets/branding/coregrid.webp`
/// (the tower-and-skyline mark): teal-green tower as the seed, orange and
/// magenta as the two accent hues the logo itself uses. Kept as named
/// constants (not buried in `ColorScheme.fromSeed`'s derived tones) so
/// screens that want the literal brand accent — not a seed-derived
/// approximation of it — have somewhere to get it from.
abstract final class CoreGridBrand {
  static const Color green = Color(0xFF1E8A6E);
  static const Color orange = Color(0xFFEE6C0E);
  static const Color magenta = Color(0xFFB81E6E);
}

/// Per-role accent (dashboard UX request: make it obvious at a glance which
/// role's dashboard is on screen) — a tint applied to the app bar and each
/// role's primary action, not a second `ColorScheme`. Keeping one shared
/// Material 3 scheme app-wide avoids the contrast/harmony bugs a fully
/// role-specific theme tree would risk; the accent is enough to
/// differentiate without that risk.
abstract final class RoleAccent {
  static const Color officer = CoreGridBrand.orange;
  static const Color staff = CoreGridBrand.magenta;

  static Color forRole(String? role) =>
      role == 'InventoryOfficer' ? officer : staff;
}

abstract final class AppTheme {
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: CoreGridBrand.green,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
