import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 600;
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1024;
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 1024;

  static int gridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  static double contentMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return 820;
    return width;
  }

  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return 48;
    if (width >= 600) return 32;
    return 18;
  }

  static double cardPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 600) return 28;
    return 20;
  }

  static double progressCircleSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return 200;
    if (width >= 600) return 180;
    return 160;
  }

  static double buttonHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 600) return 64;
    return 56;
  }

  static double iconSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 600) return 32;
    return 28;
  }

  static double fontSize(BuildContext context, {required double mobile, double? tablet, double? desktop}) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024 && desktop != null) return desktop;
    if (width >= 600 && tablet != null) return tablet;
    return mobile;
  }
}
