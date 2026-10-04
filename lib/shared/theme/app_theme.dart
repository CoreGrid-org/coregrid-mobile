import 'package:flutter/material.dart';

/// CoreGrid brand palette — "clay" edition: a warm cream canvas with soft,
/// raised surfaces and two oranges. [orange] is the vivid brand colour for
/// accents; [orangeDeep] carries text and button
/// labels (white on it is 4.7:1, WCAG AA).
abstract final class CoreGridBrand {
  /// Vivid brand orange — gradients, accents, icon fills.
  static const Color orange = Color(0xFFEE6C0E);

  /// Burnt orange for text and filled controls (AA with white).
  static const Color orangeDeep = Color(0xFFC2500A);

  /// Soft peach for containers / selected states.
  static const Color orangeLight = Color(0xFFFFE6D5);

  /// Warm near-black for primary text.
  static const Color ink = Color(0xFF2B1D14);

  /// Warm cream application canvas — clay shadows need a non-white ground
  /// to read as depth.
  static const Color cream = Color(0xFFF8F1EA);

  /// Raised card surface on [cream].
  static const Color clayWhite = Color(0xFFFFFCF9);
}

/// Shared corner-radius scale — one source for "rounded" across every
/// surface, instead of each widget picking its own number.
abstract final class AppRadius {
  static const double card = 24;
  static const double control = 18;
  static const double tile = 14;
  static const double sheet = 32;
  static const double pill = 999;
}

/// The clay surface: solid fill, generous radius and a soft, warm shadow
/// that lifts it off the cream canvas. One recipe for every raised surface
/// so depth reads the same everywhere — no gradients, no glows.
abstract final class Clay {
  static List<BoxShadow> shadows(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return [
      BoxShadow(
        color: light
            ? const Color(0xFF7A4A2A).withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.35),
        blurRadius: 24,
        offset: const Offset(0, 8),
        spreadRadius: -4,
      ),
    ];
  }

  static BoxDecoration surface(
    BuildContext context, {
    Color? color,
    double radius = AppRadius.card,
  }) => BoxDecoration(
    color: color ?? context.colors.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: shadows(context),
  );
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
    neutralContainer: Color(0xFFF1E6DC),
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

    // Warm neutrals throughout (no cool greys) so cream canvas, cards and
    // the orange read as one palette.
    final scheme = isLight
        ? seeded.copyWith(
            primary: CoreGridBrand.orangeDeep,
            onPrimary: Colors.white,
            primaryContainer: CoreGridBrand.orangeLight,
            onPrimaryContainer: const Color(0xFF5A2300),
            secondary: const Color(0xFF7A4010),
            onSecondary: Colors.white,
            secondaryContainer: const Color(0xFFFFDCC8),
            onSecondaryContainer: const Color(0xFF2F1200),
            surface: CoreGridBrand.clayWhite,
            onSurface: CoreGridBrand.ink,
            onSurfaceVariant: const Color(0xFF75655A),
            surfaceContainerLowest: CoreGridBrand.clayWhite,
            surfaceContainerLow: const Color(0xFFFBF6F1),
            surfaceContainer: const Color(0xFFF5ECE4),
            surfaceContainerHigh: const Color(0xFFF1E6DC),
            surfaceContainerHighest: const Color(0xFFEADDD1),
            outline: const Color(0xFFC9B8AA),
            outlineVariant: const Color(0xFFEFE4DA),
            error: AppColors.light.danger,
          )
        : seeded.copyWith(
            primary: const Color(0xFFFF9F5C),
            onPrimary: const Color(0xFF3D1500),
            primaryContainer: const Color(0xFF5A2600),
            onPrimaryContainer: const Color(0xFFFFDCC8),
            surface: const Color(0xFF1C1612),
            onSurface: const Color(0xFFF3E9E1),
            onSurfaceVariant: const Color(0xFFC2B2A5),
            surfaceContainerLowest: const Color(0xFF261F1A),
            surfaceContainerLow: const Color(0xFF221B17),
            surfaceContainer: const Color(0xFF2B231E),
            surfaceContainerHigh: const Color(0xFF332A24),
            surfaceContainerHighest: const Color(0xFF3C322B),
            outline: const Color(0xFF6E5F54),
            outlineVariant: const Color(0xFF3A302A),
          );

    // Cream canvas; cards (surfaceContainerLowest) sit raised on it.
    final canvas = isLight ? CoreGridBrand.cream : const Color(0xFF17120F);
    final cardColor = scheme.surfaceContainerLowest;

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
        indicatorShape: const StadiumBorder(),
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
        backgroundColor: CoreGridBrand.orangeDeep,
        foregroundColor: Colors.white,
        elevation: 3,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          backgroundColor: scheme.surfaceContainerLowest,
          side: BorderSide(color: scheme.outlineVariant),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 54),
          shape: controlShape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
          backgroundColor: CoreGridBrand.orangeDeep,
          foregroundColor: Colors.white,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 54),
          shape: controlShape,
          backgroundColor: scheme.surfaceContainerLowest,
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
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
        fillColor: scheme.surfaceContainer,
        border: inputBorder(Colors.transparent),
        enabledBorder: inputBorder(Colors.transparent),
        focusedBorder: inputBorder(scheme.primary, 1.5),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
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
        backgroundColor: isLight
            ? CoreGridBrand.ink
            : scheme.surfaceContainerHighest,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
    );
  }
}
