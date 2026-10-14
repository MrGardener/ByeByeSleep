import 'package:flutter/material.dart';

/// ByeByeSleep's design system: "Sunrise".
///
/// A deep night-sky indigo that warms into coral, amber and orchid, the
/// colours of the sky just before you get up. Every text colour below was
/// checked for WCAG AA contrast (4.5:1) against the surfaces it sits on.
abstract final class Sunrise {
  // Night (dark theme).
  static const night = Color(0xFF120E24);
  static const nightLowest = Color(0xFF0B0819);
  static const nightLow = Color(0xFF191433);
  static const nightMid = Color(0xFF1E1839);
  static const nightHigh = Color(0xFF262043);
  static const nightHighest = Color(0xFF2F2850);
  static const starlight = Color(0xFFF5F0FF);
  static const haze = Color(0xFFBDB3DA);

  // Accents.
  static const coral = Color(0xFFFF8A65);
  static const amber = Color(0xFFFFC155);
  static const orchid = Color(0xFFD49BFF);
  static const mint = Color(0xFF6EE7A8);

  // Dawn (light theme).
  static const dawn = Color(0xFFFFF8F4);
  static const ink = Color(0xFF24172A);
  static const emberDeep = Color(0xFFA93A1C);
  static const violetDeep = Color(0xFF7B3FAF);
  static const amberDeep = Color(0xFF8A5300);
  static const forest = Color(0xFF1B7A4B);

  // The hero gradient: from night through plum into the first coral light.
  // White text passes AA on every stop.
  static const dusk = Color(0xFF2A1B5C);
  static const plum = Color(0xFF6E2A78);
  static const ember = Color(0xFFC4475C);
}

/// Colours the [ColorScheme] has no slot for.
@immutable
class SunriseColors extends ThemeExtension<SunriseColors> {
  const SunriseColors({
    required this.hero,
    required this.onHero,
    required this.glow,
    required this.success,
    required this.onSuccess,
    required this.sky,
  });

  /// Background of hero cards (next alarm, quest progress).
  final Gradient hero;

  /// Text and icons on [hero].
  final Color onHero;

  /// Coral-to-amber: the big Stop button and other "wake up" moments.
  final Gradient glow;

  /// Done / passed / connected.
  final Color success;
  final Color onSuccess;

  /// Whole-screen background behind the ring screen: night sky to sunrise.
  final Gradient sky;

  /// The theme's colours; outside the app theme (plain widget tests), the
  /// defaults for its brightness.
  static SunriseColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<SunriseColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  static const _hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Sunrise.dusk, Sunrise.plum, Sunrise.ember],
    stops: [0, 0.55, 1],
  );

  static const _glow = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Sunrise.coral, Color(0xFFFFB547)],
  );

  static const dark = SunriseColors(
    hero: _hero,
    onHero: Colors.white,
    glow: _glow,
    success: Sunrise.mint,
    onSuccess: Color(0xFF00391F),
    sky: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Sunrise.nightLowest, Color(0xFF1A1240), Color(0xFF3A1838)],
      stops: [0, 0.55, 1],
    ),
  );

  static const light = SunriseColors(
    hero: _hero,
    onHero: Colors.white,
    glow: _glow,
    success: Sunrise.forest,
    onSuccess: Colors.white,
    sky: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Sunrise.dawn, Color(0xFFFFEDE3), Color(0xFFFFDCCB)],
    ),
  );

  @override
  SunriseColors copyWith({
    Gradient? hero,
    Color? onHero,
    Gradient? glow,
    Color? success,
    Color? onSuccess,
    Gradient? sky,
  }) => SunriseColors(
    hero: hero ?? this.hero,
    onHero: onHero ?? this.onHero,
    glow: glow ?? this.glow,
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    sky: sky ?? this.sky,
  );

  @override
  SunriseColors lerp(SunriseColors? other, double t) {
    if (other == null) return this;
    return SunriseColors(
      hero: Gradient.lerp(hero, other.hero, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      glow: Gradient.lerp(glow, other.glow, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      sky: Gradient.lerp(sky, other.sky, t)!,
    );
  }
}

/// Builds the app's light and dark [ThemeData].
abstract final class AppTheme {
  /// Dark first: a bedside alarm should not glare at night. Light follows
  /// the phone's setting when it is on.
  static const mode = ThemeMode.system;

  static const darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Sunrise.coral,
    onPrimary: Color(0xFF3B0D00),
    primaryContainer: Color(0xFF7A2A52),
    onPrimaryContainer: Color(0xFFFFD9D0),
    secondary: Sunrise.amber,
    onSecondary: Color(0xFF3A2500),
    secondaryContainer: Color(0xFF4D3812),
    onSecondaryContainer: Color(0xFFFFE1A8),
    tertiary: Sunrise.orchid,
    onTertiary: Color(0xFF3A0B5C),
    tertiaryContainer: Color(0xFF4F2A78),
    onTertiaryContainer: Color(0xFFF1DBFF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Sunrise.night,
    onSurface: Sunrise.starlight,
    onSurfaceVariant: Sunrise.haze,
    surfaceDim: Sunrise.nightLowest,
    surfaceBright: Color(0xFF3A3260),
    surfaceContainerLowest: Sunrise.nightLowest,
    surfaceContainerLow: Sunrise.nightLow,
    surfaceContainer: Sunrise.nightMid,
    surfaceContainerHigh: Sunrise.nightHigh,
    surfaceContainerHighest: Sunrise.nightHighest,
    outline: Color(0xFF857BA6),
    outlineVariant: Color(0xFF3B3360),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Sunrise.starlight,
    onInverseSurface: Sunrise.nightMid,
    inversePrimary: Color(0xFFB33D22),
    surfaceTint: Colors.transparent,
  );

  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Sunrise.emberDeep,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFFDBD0),
    onPrimaryContainer: Color(0xFF3F0B00),
    secondary: Sunrise.amberDeep,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFFDDB0),
    onSecondaryContainer: Color(0xFF2C1700),
    tertiary: Sunrise.violetDeep,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFF2DAFF),
    onTertiaryContainer: Color(0xFF2E004E),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Sunrise.dawn,
    onSurface: Sunrise.ink,
    onSurfaceVariant: Color(0xFF5C4A5E),
    surfaceDim: Color(0xFFE8D3C9),
    surfaceBright: Sunrise.dawn,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFFFF1EA),
    surfaceContainer: Color(0xFFFCEAE2),
    surfaceContainerHigh: Color(0xFFF7E2D9),
    surfaceContainerHighest: Color(0xFFF1DAD0),
    outline: Color(0xFF8E7A8C),
    outlineVariant: Color(0xFFE0CBC9),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF3A2C3E),
    onInverseSurface: Color(0xFFFFEDE6),
    inversePrimary: Color(0xFFFFB59E),
    surfaceTint: Colors.transparent,
  );

  static ThemeData dark() => _build(darkScheme, SunriseColors.dark);
  static ThemeData light() => _build(lightScheme, SunriseColors.light);

  /// Rounded corner radii used everywhere.
  static const radiusSmall = 12.0;
  static const radius = 20.0;
  static const radiusLarge = 28.0;

  static const _tabular = [FontFeature.tabularFigures()];

  /// System font only (Roboto / Google Sans on Pixel): big confident
  /// numerals, bold titles, calm body text.
  static TextTheme _text(TextTheme base) => base.copyWith(
    displayLarge: base.displayLarge!.copyWith(
      fontSize: 72,
      fontWeight: FontWeight.w300,
      letterSpacing: -2,
      height: 1.05,
      fontFeatures: _tabular,
    ),
    displayMedium: base.displayMedium!.copyWith(
      fontSize: 56,
      fontWeight: FontWeight.w400,
      letterSpacing: -1.5,
      height: 1.1,
      fontFeatures: _tabular,
    ),
    displaySmall: base.displaySmall!.copyWith(
      fontSize: 44,
      fontWeight: FontWeight.w400,
      letterSpacing: -1,
      height: 1.1,
      fontFeatures: _tabular,
    ),
    headlineLarge: base.headlineLarge!.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineMedium: base.headlineMedium!.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.25,
    ),
    headlineSmall: base.headlineSmall!.copyWith(fontWeight: FontWeight.w700),
    titleLarge: base.titleLarge!.copyWith(fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium!.copyWith(fontWeight: FontWeight.w600),
    titleSmall: base.titleSmall!.copyWith(fontWeight: FontWeight.w600),
    labelLarge: base.labelLarge!.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
    labelMedium: base.labelMedium!.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge!.copyWith(height: 1.4),
    bodyMedium: base.bodyMedium!.copyWith(height: 1.4),
  );

  static ThemeData _build(ColorScheme s, SunriseColors extra) {
    final base = ThemeData(colorScheme: s, useMaterial3: true);
    final text = _text(base.textTheme);
    const pill = StadiumBorder();
    const buttonSize = Size(64, 52);
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return base.copyWith(
      scaffoldBackgroundColor: s.surface,
      textTheme: text,
      extensions: [extra],
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: s.surface,
        foregroundColor: s.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: text.headlineSmall!.copyWith(
          color: s.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.25,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: s.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: s.primaryContainer,
        indicatorShape: pill,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? s.onPrimaryContainer
                : s.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected)
                ? s.onSurface
                : s.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: s.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        minVerticalPadding: 12,
        iconColor: s.onSurfaceVariant,
        titleTextStyle: text.titleMedium!.copyWith(color: s.onSurface),
        subtitleTextStyle: text.bodyMedium!.copyWith(color: s.onSurfaceVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: pill,
          textStyle: text.labelLarge!.copyWith(fontSize: 16),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: pill,
          foregroundColor: s.onSurface,
          side: BorderSide(color: s.outline, width: 1.5),
          textStyle: text.labelLarge!.copyWith(fontSize: 16),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: pill,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: s.primary,
        foregroundColor: s.onPrimary,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 6,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        largeSizeConstraints: const BoxConstraints.tightFor(
          width: 80,
          height: 80,
        ),
        extendedTextStyle: text.labelLarge!.copyWith(fontSize: 16),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? s.onSurface.withValues(alpha: 0.38)
              : states.contains(WidgetState.selected)
              ? s.onPrimary
              : s.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? s.onSurface.withValues(alpha: 0.12)
              : states.contains(WidgetState.selected)
              ? s.primary
              : s.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : s.outline,
        ),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: s.primary,
        inactiveTrackColor: s.surfaceContainerHighest,
        thumbColor: s.primary,
        overlayColor: s.primary.withValues(alpha: 0.12),
        activeTickMarkColor: s.onPrimary.withValues(alpha: 0.6),
        inactiveTickMarkColor: s.onSurfaceVariant.withValues(alpha: 0.6),
        trackHeight: 8,
        valueIndicatorColor: s.primary,
        valueIndicatorTextStyle: text.labelLarge!.copyWith(color: s.onPrimary),
        showValueIndicator: ShowValueIndicator.onDrag,
      ),
      chipTheme: ChipThemeData(
        shape: pill,
        backgroundColor: s.surfaceContainerHigh,
        selectedColor: s.primary,
        checkmarkColor: s.onPrimary,
        side: BorderSide(color: s.outlineVariant),
        labelStyle: text.labelLarge!.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? s.onPrimary
                : s.onSurface,
          ),
        ),
        secondaryLabelStyle: text.labelLarge!.copyWith(
          color: s.onPrimaryContainer,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(48, 48),
          selectedBackgroundColor: s.primaryContainer,
          selectedForegroundColor: s.onPrimaryContainer,
          side: BorderSide(color: s.outlineVariant),
          textStyle: text.labelLarge,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: s.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: s.surfaceContainerLow,
        dragHandleColor: s.outline,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: s.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        titleTextStyle: text.headlineSmall!.copyWith(color: s.onSurface),
        contentTextStyle: text.bodyLarge!.copyWith(color: s.onSurfaceVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: s.inverseSurface,
        contentTextStyle: text.bodyLarge!.copyWith(color: s.onInverseSurface),
        actionTextColor: s.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: s.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        labelStyle: TextStyle(color: s.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: s.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: s.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: s.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: s.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: s.error, width: 2),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: s.primary,
        linearTrackColor: s.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 8,
        borderRadius: BorderRadius.circular(8),
      ),
      dividerTheme: DividerThemeData(
        color: s.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: s.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: rounded,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(s.surfaceContainerHigh),
          shape: WidgetStatePropertyAll(rounded),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: s.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        hourMinuteShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        dayPeriodShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        dialBackgroundColor: s.surfaceContainerHighest,
        dialHandColor: s.primary,
        hourMinuteColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? s.primaryContainer
              : s.surfaceContainerHighest,
        ),
        hourMinuteTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? s.onPrimaryContainer
              : s.onSurface,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: s.inverseSurface,
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        textStyle: text.bodySmall!.copyWith(color: s.onInverseSurface),
      ),
    );
  }
}
