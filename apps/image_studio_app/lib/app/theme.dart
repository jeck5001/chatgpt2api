import 'package:flutter/material.dart';

ThemeData buildImageStudioTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFE8A84A),
    brightness: Brightness.dark,
  );
  return ThemeData(
    colorScheme: scheme,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF15120E),
    useMaterial3: true,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
    ),
  );
}
