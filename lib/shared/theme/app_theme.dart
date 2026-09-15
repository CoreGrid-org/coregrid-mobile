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

/// Shared corner-radius scale — one source for "rounded" across every
/// surface, instead of each widget picking its own number.
abstract final class AppRadius {
  static const double card = 20;
  static const double control = 16;
  static const double pill = 999;
}

abstract final class AppTheme {
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: CoreGridBrand.green,
      brightness: brightness,
    );

    // A plain, near-white surface for the light theme rather than Material
    // 3's default seed-tinted one — "white background, premium" was the
    // explicit ask, and M3's automatic tinting reads as a colored app,
    // not a neutral enterprise one. Dark mode keeps the seed-derived
    // surfaces as-is; the request was about the light theme's look.
    final scheme = isLight
        ? colorScheme.copyWith(
            surface: Colors.white,
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: const Color(0xFFFAFAFA),
            surfaceContainer: const Color(0xFFF5F5F5),
            surfaceContainerHigh: const Color(0xFFF0F0F0),
            surfaceContainerHighest: const Color(0xFFEDEDED),
          )
        : colorScheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? Colors.white : scheme.surface,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: isLight ? Colors.white : scheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.08),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: isLight ? Colors.white : scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide.none,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          side: BorderSide(color: scheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? scheme.surfaceContainerLow : scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
