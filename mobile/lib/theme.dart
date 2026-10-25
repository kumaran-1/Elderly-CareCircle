import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFFF5F8F6);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF18332B);
  static const muted = Color(0xFF5D7169);
  static const accent = Color(0xFF2E9B72);
  static const warning = Color(0xFFD58A18);
  static const danger = Color(0xFFD94C4C);
  static const sky = Color(0xFF3E8FA3);
  static const lavender = Color(0xFF8064A8);

  static const colorScheme = ColorScheme.light(
    primary: accent,
    secondary: warning,
    tertiary: sky,
    surface: surface,
    onSurface: ink,
    onPrimary: Colors.white,
    onSecondary: ink,
    error: danger,
    onError: Colors.white,
    surfaceContainerHighest: Color(0xFFE8F0EC),
  );
}
