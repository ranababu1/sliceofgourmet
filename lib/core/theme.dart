import 'package:flutter/material.dart';

const _brandPrimary = Color(0xFF2F855A);
const _brandAccent = Color(0xFFFFB703);

final lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: _brandPrimary,
    primary: _brandPrimary,
    secondary: _brandAccent,
    brightness: Brightness.light,
  ),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFF4F5F7),
  appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(letterSpacing: -0.3),
    titleLarge: TextStyle(letterSpacing: -0.2),
  ),
  cardTheme: CardThemeData(
    elevation: 1,
    margin: const EdgeInsets.all(8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  ),
);

final darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: _brandPrimary,
    primary: _brandPrimary,
    secondary: _brandAccent,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFF0B1220),
  appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(letterSpacing: -0.3),
    titleLarge: TextStyle(letterSpacing: -0.2),
  ),
  cardTheme: CardThemeData(
    elevation: 1,
    margin: const EdgeInsets.all(8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  ),
);
