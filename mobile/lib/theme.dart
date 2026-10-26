import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFFF7F3EA);
  static const surface = Color(0xFFFFFCF6);
  static const surfaceBorder = Color(0xFFE7DFD1);
  static const subtle = Color(0xFFF1EBDF);

  static const ink = Color(0xFF1E3A31);
  static const muted = Color(0xFF68776F);

  static const teal = Color(0xFF1F6F5C);
  static const tealDark = Color(0xFF155346);
  static const tealLight = Color(0xFFDCEBE5);

  static const coral = Color(0xFFE08A6A);
  static const coralLight = Color(0xFFFBE7DC);

  static const amber = Color(0xFFD99A2B);
  static const amberLight = Color(0xFFFCF0D8);

  static const green = Color(0xFF3E8B67);
  static const sky = Color(0xFF4C8FA3);
  static const lavender = Color(0xFF826FA8);

  static const sosRed = Color(0xFFC94B45);
  static const sosRedLight = Color(0xFFF9E3E1);
  static const danger = sosRed;
  static const warning = amber;

  static const accent = teal;

  static const spacingXs = 4.0;
  static const spacingSm = 8.0;
  static const spacingMd = 16.0;
  static const spacingLg = 24.0;
  static const spacingXl = 32.0;
  static const spacingXxl = 48.0;
  static const spacingXxl2 = 64.0;

  static const radiusXs = 8.0;
  static const radiusSmall = 12.0;
  static const radiusMedium = 16.0;
  static const radiusLarge = 22.0;
  static const radiusXLarge = 28.0;
  static const radiusFull = 999.0;

  static const fontSizeXs = 11.0;
  static const fontSizeSm = 13.0;
  static const fontSizeMd = 15.0;
  static const fontSizeLg = 18.0;
  static const fontSizeXl = 22.0;
  static const fontSizeXxl = 28.0;
  static const fontSizeDisplay = 36.0;
  static const fontSizeHero = 48.0;

  static const bodySm = TextStyle(
    fontSize: fontSizeSm,
    color: muted,
    height: 1.4,
  );

  static const colorScheme = ColorScheme.light(
    primary: teal,
    onPrimary: Colors.white,
    primaryContainer: tealLight,
    onPrimaryContainer: tealDark,
    secondary: coral,
    onSecondary: ink,
    secondaryContainer: coralLight,
    onSecondaryContainer: ink,
    tertiary: amber,
    onTertiary: ink,
    surface: surface,
    onSurface: ink,
    onSurfaceVariant: muted,
    error: sosRed,
    onError: Colors.white,
    outline: surfaceBorder,
    surfaceContainerHighest: subtle,
  );
}
