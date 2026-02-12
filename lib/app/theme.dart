import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1D3557));

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF1F5F9),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
  );
}

ThemeData buildAppDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1D3557),
    brightness: Brightness.dark,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
  );
}
