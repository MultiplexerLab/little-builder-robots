import 'package:flutter/material.dart';

/// Colour tokens (DES-01). No other colours on child screens.
abstract final class AppColors {
  static const navy = Color(0xFF1E2A4A);
  static const sky = Color(0xFFDFF1FF);
  static const roboBlue = Color(0xFF7FC8F8);
  static const grass = Color(0xFF8FD694);
  static const success = Color(0xFF1F7A4A);
  static const sunny = Color(0xFFFFC93C);
  static const tangerine = Color(0xFFFF8A3D);
  static const mint = Color(0xFF9CF6C2);
  static const cloud = Color(0xFFEEF3F9);
  static const danger = Color(0xFFB23A1E);
  static const white = Color(0xFFFFFFFF);

  /// Pale Sunny fill for the selected part tile (DES-06).
  static const sunnyPale = Color(0xFFFFE6A3);

  /// Navy at low opacity, for scrims behind Pause and reveals (DES-07).
  static const scrim = Color(0xB31E2A4A);

  /// The six robot paints (WRK-06), by the id stored in RobotConfig.colour.
  /// Each also has a pattern, so colour is never the only signal (DES-10).
  static const paints = <String, Color>{
    'sunny': sunny,
    'roboBlue': roboBlue,
    'tangerine': tangerine,
    'mint': mint,
    'grass': grass,
    'cloud': cloud,
  };
}

/// Size tokens in logical points (DES-03 to DES-07, NFR-05).
abstract final class AppSizes {
  static const childTarget = 64.0;
  static const childPrimary = 96.0;
  static const grownUpsTarget = 48.0;
  static const targetSpacing = 16.0;
  static const partTile = 96.0;
  static const jumpIcon = 120.0;

  static const outline = 3.0;
  static const outlineThick = 4.0;
  static const shadow = 6.0;
  static const pressDuration = Duration(milliseconds: 100);
}

/// Type tokens (DES-02). Fredoka on child screens, Nunito Sans for Grown-ups.
abstract final class AppText {
  static const fredoka = 'Fredoka';
  static const nunitoSans = 'NunitoSans';

  static TextStyle _style(String family, double size, double weight) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: FontWeight.values[(weight ~/ 100) - 1],
        fontVariations: [FontVariation.weight(weight)],
        color: AppColors.navy,
        height: 1.2,
      );

  static final TextStyle display = _style(fredoka, 50, 700);
  static final TextStyle title = _style(fredoka, 28, 700);
  static final TextStyle button = _style(fredoka, 24, 700);
  static final TextStyle body = _style(fredoka, 18, 500);
  static final TextStyle label = _style(fredoka, 14, 600);

  static TextTheme _textTheme(String family, {required bool calm}) {
    final bodyWeight = calm ? 400.0 : 500.0;
    return TextTheme(
      displayLarge: _style(family, 50, 700),
      titleLarge: _style(family, 28, 700),
      labelLarge: _style(family, 24, 700),
      bodyLarge: _style(family, 18, bodyWeight),
      bodyMedium: _style(family, 18, bodyWeight),
      labelMedium: _style(family, 14, 600),
    );
  }

  static TextTheme get childTheme => _textTheme(fredoka, calm: false);
  static TextTheme get grownUpsTheme => _textTheme(nunitoSans, calm: true);
}

abstract final class AppTheme {
  /// Theme for every child-facing screen.
  static ThemeData child() => ThemeData(
    useMaterial3: true,
    fontFamily: AppText.fredoka,
    scaffoldBackgroundColor: AppColors.sky,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.sunny,
      primary: AppColors.sunny,
      onPrimary: AppColors.navy,
      secondary: AppColors.roboBlue,
      surface: AppColors.white,
      onSurface: AppColors.navy,
      error: AppColors.danger,
    ),
    textTheme: AppText.childTheme,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: NoSplash.splashFactory,
  );

  /// Calmer theme for the Parent gate and Grown-ups area (DES-11).
  static ThemeData grownUps() => ThemeData(
    useMaterial3: true,
    fontFamily: AppText.nunitoSans,
    scaffoldBackgroundColor: AppColors.cloud,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      onPrimary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.navy,
      error: AppColors.danger,
    ),
    textTheme: AppText.grownUpsTheme,
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? AppColors.success : null,
      ),
    ),
  );
}
