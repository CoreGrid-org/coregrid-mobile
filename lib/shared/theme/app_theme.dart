import 'package:flutter/material.dart';

/// CoreGrid's brand palette, sourced from `assets/branding/coregrid.webp`
/// (the tower-and-skyline mark): teal-green tower as the seed, orange and
/// magenta as the two accent hues the logo itself uses. Kept as named
/// constants so screens that want the literal brand hue — not a seed-derived
/// approximation of it — have somewhere to get it from.
abstract final class CoreGridBrand {
  static const Color green = Color(0xFF1E8A6E);

  /// The darker brand green used as the interactive `primary` on light
  /// surfaces — [green] itself is too light for white text (WCAG AA).
  static const Color greenDeep = Color(0xFF12664F);
  static const Color orange = Color(0xFFEE6C0E);
  static const Color magenta = Color(0xFFB81E6E);

  /// Near-black used for panels drawn over the camera preview.
  static const Color ink = Color(0xFF111827);
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

  static const light = AppColors(
    success: Color(0xFF17754A),
    successContainer: Color(0xFFE3F4EA),
    warning: Color(0xFF9A5B00),
    warningContainer: Color(0xFFFDF0DC),
    info: Color(0xFF1F5FB8),
    infoContainer: Color(0xFFE6EFFC),
    danger: Color(0xFFB42318),
    dangerContainer: Color(0xFFFDECEA),
    neutral: Color(0xFF4B5563),
    neutralContainer: Color(0xFFEEF0F3),
  );

  static const dark = AppColors(
    success: Color(0xFF7BD6A4),
    successContainer: Color(0xFF113524),
    warning: Color(0xFFF4C36B),
    warningContainer: Color(0xFF3A2A0C),
    info: Color(0xFF9CC2FA),
    infoContainer: Color(0xFF14284A),
    danger: Color(0xFFF7A39A),
    dangerContainer: Color(0xFF45160F),
    neutral: Color(0xFFC3C9D2),
    neutralContainer: Color(0xFF2A2F36),
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
    final seeded = ColorScheme.fromSeed(
      seedColor: CoreGridBrand.green,
      brightness: brightness,
    );

    // Light: a cool-grey canvas with white, hairline-bordered cards — the
    // layered "enterprise" look — and the deep brand green as primary.
    final scheme = isLight
        ? seeded.copyWith(
            primary: CoreGridBrand.greenDeep,
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFDDF1E9),
            onPrimaryContainer: const Color(0xFF0B3F31),
            surface: Colors.white,
            onSurface: const Color(0xFF111827),
            onSurfaceVariant: const Color(0xFF5B6472),
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: const Color(0xFFF6F7F9),
            surfaceContainer: const Color(0xFFF1F3F5),
            surfaceContainerHigh: const Color(0xFFEBEEF1),
            surfaceContainerHighest: const Color(0xFFE4E7EB),
            outline: const Color(0xFFB8BEC7),
            outlineVariant: const Color(0xFFE4E7EB),
            error: AppColors.light.danger,
          )
        : seeded;

    final canvas = isLight ? const Color(0xFFF6F7F9) : scheme.surface;
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
      splashFactory: InkSparkle.splashFactory,
      extensions: [isLight ? AppColors.light : AppColors.dark],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: canvas,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
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
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: isLight ? Colors.white : scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
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
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: controlShape,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? const Color(0xFFF3F4F6)
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
