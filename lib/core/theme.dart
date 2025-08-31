import 'package:flutter/material.dart';

const _brandPrimary = Color(0xFF2F855A);
const _brandAccent = Color(0xFFFFB703);

TextTheme _textTheme(TextTheme base) {
  // We already registered the font in pubspec, so just use fontFamily below.
  return base.copyWith(
    headlineSmall: base.headlineSmall?.copyWith(letterSpacing: -0.3),
    titleLarge: base.titleLarge?.copyWith(letterSpacing: -0.2),
  );
}

ThemeData _baseTheme(Brightness brightness) {
  final cs = ColorScheme.fromSeed(
    seedColor: _brandPrimary,
    primary: _brandPrimary,
    secondary: _brandAccent,
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    fontFamily: 'TASAExplorer',
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFF4F5F7)
        : const Color(0xFF0B1220),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    textTheme: _textTheme(ThemeData(brightness: brightness).textTheme),
    cardTheme: const CardThemeData(
      elevation: 1,
      margin: EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
}

final lightTheme = _baseTheme(Brightness.light);
final darkTheme = _baseTheme(Brightness.dark);
