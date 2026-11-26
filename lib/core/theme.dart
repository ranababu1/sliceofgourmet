import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Brand palette, matching the sliceofgourmet.com theme.
class Brand {
  static const herb = Color(0xFF2A7348);
  static const herbLight = Color(0xFF6FCF97);
  static const herbSoft = Color(0xFFE3F2E8);
  static const paper = Color(0xFFFFFDF9);
  static const cream = Color(0xFFF6F1E9);
  static const line = Color(0xFFE6DFD3);
  static const ink = Color(0xFF1F1D1A);
  static const muted = Color(0xFF5F5A52);
  static const spice = Color(0xFFC2462B);
  static const star = Color(0xFFE8A317);

  static const darkPaper = Color(0xFF171614);
  static const darkCream = Color(0xFF211F1C);
  static const darkCard = Color(0xFF1E1C19);
  static const darkLine = Color(0xFF36322C);
  static const darkInk = Color(0xFFF1EDE6);
}

/// Serif display style (Playfair Display, a variable font).
TextStyle display(double size, {double weight = 700, Color? color}) =>
    TextStyle(
      fontFamily: 'Playfair',
      fontSize: size,
      fontVariations: [FontVariation('wght', weight)],
      fontWeight: weight >= 600 ? FontWeight.w700 : FontWeight.w400,
      height: 1.15,
      letterSpacing: -0.2,
      color: color,
    );

ThemeData _theme(Brightness b) {
  final light = b == Brightness.light;
  final cs = ColorScheme.fromSeed(
    seedColor: Brand.herb,
    brightness: b,
  ).copyWith(
    primary: light ? Brand.herb : Brand.herbLight,
    onPrimary: light ? Colors.white : const Color(0xFF0F2418),
    primaryContainer: light ? Brand.herbSoft : const Color(0xFF1D3527),
    onPrimaryContainer: light ? const Color(0xFF0F2418) : Brand.herbSoft,
    secondary: light ? Brand.spice : const Color(0xFFEF8A6F),
    tertiary: Brand.star,
    surface: light ? Brand.paper : Brand.darkPaper,
    onSurface: light ? Brand.ink : Brand.darkInk,
    onSurfaceVariant: light ? Brand.muted : const Color(0xFFB9B1A5),
    surfaceContainerLowest: light ? Colors.white : Brand.darkCard,
    surfaceContainerLow: light ? Colors.white : Brand.darkCard,
    surfaceContainer: light ? Brand.cream : Brand.darkCream,
    surfaceContainerHigh: light ? Brand.cream : Brand.darkCream,
    surfaceContainerHighest:
        light ? const Color(0xFFF0E9DD) : const Color(0xFF2A2723),
    outline: light ? const Color(0xFFCFC6B8) : const Color(0xFF4A453D),
    outlineVariant: light ? Brand.line : Brand.darkLine,
  );

  final base = ThemeData(brightness: b, useMaterial3: true);
  final text = base.textTheme.apply(
    fontFamily: 'TASAExplorer',
    bodyColor: cs.onSurface,
    displayColor: cs.onSurface,
  );

  return base.copyWith(
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    textTheme: text.copyWith(
      headlineLarge: display(32, color: cs.onSurface),
      headlineMedium: display(28, color: cs.onSurface),
      headlineSmall: display(24, color: cs.onSurface),
      titleLarge: display(21, color: cs.onSurface),
    ),
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      titleTextStyle: display(22, color: cs.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cs.surfaceContainerLowest,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: cs.outlineVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: cs.surfaceContainer,
      selectedColor: cs.primaryContainer,
      side: BorderSide(color: cs.outlineVariant),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
          fontFamily: 'TASAExplorer',
          fontWeight: FontWeight.w600,
          color: cs.onSurface),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(
            fontFamily: 'TASAExplorer', fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cs.surface,
      showDragHandle: true,
    ),
    dividerTheme: DividerThemeData(color: cs.outlineVariant, space: 1),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

final lightTheme = _theme(Brightness.light);
final darkTheme = _theme(Brightness.dark);
