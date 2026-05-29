import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand Colors (Vietnamese Nature Landscapes)
  static const Color primary = Color(0xff006e1c);
  static const Color primaryContainer = Color(0xff4caf50);

  // Secondary Brand Colors (Transit/Vibrancy Accents)
  static const Color secondary = Color(0xff9f4200);
  static const Color secondaryContainer = Color(0xfffd6c00);

  // Surface Hierarchy (Tonal Layering - No 1px lines!)
  static const Color background = Color(0xfff9f9f9);
  static const Color surface = Color(0xfff9f9f9);
  static const Color surfaceContainerLow = Color(0xfff3f3f3);
  static const Color surfaceContainerLowest = Color(0xffffffff);
  static const Color surfaceContainerHigh = Color(0xffe8e8e8);
  static const Color surfaceContainerHighest = Color(0xffe2e2e2);

  // Text & Content Tinting
  static const Color onSurface = Color(0xff1a1c1c);
  static const Color onSurfaceVariant = Color(0xff3f4a3c);
  static const Color onPrimary = Color(0xffffffff);
  static const Color onSecondary = Color(0xffffffff);

  // Status Colors
  static const Color success = Color(0xff106d20);
  static const Color successContainer = Color(0xff9df898);
  static const Color error = Color(0xffba1a1a);
  static const Color errorContainer = Color(0xffffdad6);
  static const Color warning = Color(0xff9f4200);
  static const Color warningContainer = Color(0xfffd6c00);

  // Outline (Subtle ghost boundaries - max 20% opacity recommended)
  static const Color outline = Color(0xff6f7a6b);
  static const Color outlineVariant = Color(0xffbecab9);
}
