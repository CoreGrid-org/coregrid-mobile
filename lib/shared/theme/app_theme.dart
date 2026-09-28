import 'package:flutter/material.dart';

/// CoreGrid brand palette — orange & white edition.
/// Primary accent is the brand orange; white surfaces give a clean, warm feel.
abstract final class CoreGridBrand {
  /// Primary brand orange.
  static const Color orange = Color(0xFFEE6C0E);

  /// Deeper orange for text/interactive elements on light backgrounds (WCAG AA).
  static const Color orangeDeep = Color(0xFFCC5500);

  /// Soft warm orange for containers / highlights.
  static const Color orangeLight = Color(0xFFFFF0E6);

  /// Near-black for ink / primary text.
  static const Color ink = Color(0xFF1A1A1A);

  /// Warm off-white scaffold.
  static const Color warmWhite = Color(0xFFFAF8F6);
}

/// Shared corner-radius scale — one source for "rounded" across every
/// surface, instead of each widget picking its own number.
abstract final class AppRadius {
  static const double card = 16;
  static const double control = 12;
  static const double pill = 999;
}

/// 4-pt spacing scale. Screens use these rather than ad-hoc numbers so
/// gutters and gaps line up from page to page.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal page gutter.
  static const double page = 20;

  /// Standard scrollable page body padding.
  static const pageInsets = EdgeInsets.fromLTRB(page, sm, page, xxl);

  /// Page body padding that clears an extended FAB.
  static const pageInsetsFab = EdgeInsets.fromLTRB(page, sm, page, 96);

  /// Gap above a [SectionHeader] that follows other content.
  static const sectionGap = EdgeInsets.only(top: xl, bottom: sm);
}

/// Shorthands for the theme lookups every screen repeats.
extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  /// Secondary copy: body / small text in `onSurfaceVariant`.
  TextStyle? get mutedBody =>
      text.bodyMedium?.copyWith(color: colors.onSurfaceVariant);
  TextStyle? get mutedSmall =>
      text.bodySmall?.copyWith(color: colors.onSurfaceVariant);
}

/// Semantic status colours Material 3 doesn't provide (success / warning /
/// info) — a [ThemeExtension] so they flip correctly in dark mode. Read with
/// `AppColors.of(context)`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    required this.danger,
    required this.dangerContainer,
    required this.neutral,
    required this.neutralContainer,
  });

  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;
  final Color danger;
  final Color dangerContainer;
  final Color neutral;
  final Color neutralContainer;

  /// Falls back to the brightness-matched palette when the ambient theme
  /// wasn't built by [AppTheme] (e.g. a bare `MaterialApp` in widget tests).
  static AppColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  // Light: warm, orange-tinted semantic colours that sit naturally alongside
  // the brand orange primary without competing with it.
  static const light = AppColors(
    success: Color(0xFF2E7D32),
    successContainer: Color(0xFFE8F5E9),
    warning: Color(0xFF9A5B00),
    warningContainer: Color(0xFFFFF3CD),
    info: Color(0xFF1565C0),
    infoContainer: Color(0xFFE3F0FF),
    danger: Color(0xFFB42318),
    dangerContainer: Color(0xFFFDECEA),
    neutral: Color(0xFF5A5A5A),
    neutralContainer: Color(0xFFF0EEEB),
  );

  static const dark = AppColors(
    success: Color(0xFF81C784),
    successContainer: Color(0xFF1B3A1C),
    warning: Color(0xFFFFB74D),
    warningContainer: Color(0xFF3A2800),
    info: Color(0xFF90CAF9),
    infoContainer: Color(0xFF0D2A4A),
    danger: Color(0xFFEF9A9A),
    dangerContainer: Color(0xFF4A1010),
    neutral: Color(0xFFBDBDBD),
    neutralContainer: Color(0xFF2C2C2C),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      success: l(success, other.success),
      successContainer: l(successContainer, other.successContainer),
      warning: l(warning, other.warning),
      warningContainer: l(warningContainer, other.warningContainer),
      info: l(info, other.info),
      infoContainer: l(infoContainer, other.infoContainer),
      danger: l(danger, other.danger),
      dangerContainer: l(dangerContainer, other.dangerContainer),
      neutral: l(neutral, other.neutral),
      neutralContainer: l(neutralContainer, other.neutralContainer),
    );
  }
}

abstract final class AppTheme {
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    // Seed from the brand orange so Material 3 generates a harmonious
    // tonal palette. Then we override key roles to keep surfaces white and
    // primary squarely on orange.
    final seeded = ColorScheme.fromSeed(
      seedColor: CoreGridBrand.orange,
      brightness: brightness,
    );

    final scheme = isLight
        ? seeded.copyWith(
            primary: CoreGridBrand.orangeDeep,
            onPrimary: Colors.white,
            primaryContainer: CoreGridBrand.orangeLight,
            onPrimaryContainer: const Color(0xFF5C1F00),
            secondary: const Color(0xFF7A4010),
            onSecondary: Colors.white,
            secondaryContainer: const Color(0xFFFFDCC8),
            onSecondaryContainer: const Color(0xFF2F1200),
            // Keep surfaces bright white / warm-grey for the clean look.
            surface: Colors.white,
            onSurface: CoreGridBrand.ink,
            onSurfaceVariant: const Color(0xFF6B6460),
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: const Color(0xFFFAF8F6),
            surfaceContainer: const Color(0xFFF5F2EF),
            surfaceContainerHigh: const Color(0xFFEFEBE7),
            surfaceContainerHighest: const Color(0xFFE8E3DE),
            outline: const Color(0xFFBCB4AC),
            outlineVariant: const Color(0xFFE8E3DE),
            error: AppColors.light.danger,
          )
        : seeded.copyWith(
            primary: const Color(0xFFFFB77A),
            onPrimary: const Color(0xFF4A1800),
            primaryContainer: const Color(0xFF6B2D00),
            onPrimaryContainer: const Color(0xFFFFDCC8),
          );

    // Light: warm white canvas; dark: dark surface.
    final canvas = isLight ? CoreGridBrand.warmWhite : scheme.surface;
    final cardColor = isLight ? Colors.white : scheme.surfaceContainer;

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: canvas,
      visualDensity: VisualDensity.standard,
      // Subtle ripple — no heavy splash animation.
      splashFactory: InkRipple.splashFactory,
      extensions: [isLight ? AppColors.light : AppColors.dark],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: canvas,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        toolbarHeight: 72,
        titleSpacing: AppSpacing.page,
        titleTextStyle: text.headlineSmall?.copyWith(
          color: scheme.onSurface,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      // The shell draws the floating container; the bar itself is clear.
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        // Orange tint on the selected indicator.
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall?.copyWith(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        focusElevation: 4,
        hoverElevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: text.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: controlShape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: controlShape,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
          foregroundColor: scheme.primary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: controlShape,
          textStyle: text.labelLarge,
          foregroundColor: scheme.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? const Color(0xFFF5F2EF)
            : scheme.surfaceContainerHigh,
        border: inputBorder(Colors.transparent),
        enabledBorder: inputBorder(Colors.transparent),
        focusedBorder: inputBorder(scheme.primary, 1.5),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        iconColor: scheme.onSurfaceVariant,
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        backgroundColor: isLight ? const Color(0xFF2C2C2C) : cardColor,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: isLight ? Colors.white : scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? Colors.white : scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
    );
  }
}
