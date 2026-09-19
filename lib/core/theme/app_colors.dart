import 'package:flutter/material.dart';

/// Design tokens — colour.
///
/// A brand pair (violet → indigo) used for gradients on primary actions and
/// hero moments, a warm accent for highlights, a neutral grey scale, and
/// semantic colours used for status. Gradients are used sparingly — one or
/// two hero surfaces per screen, never as decoration on every element.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF3F3BF0);
  static const Color primaryHover = Color(0xFF322FC2);
  static const Color primaryTint = Color(0xFFEEEEFE);
  static const Color primarySoft = Color(0xFF6E67FF);
  static const Color primaryDeep = Color(0xFF2A2792);

  // Warm accent — used sparingly for highlights, badges and hero details.
  static const Color accent = Color(0xFFFF8A3D);
  static const Color accentTint = Color(0xFFFFEFE2);

  // Neutrals
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F7F9);
  static const Color surfaceAlt = Color(0xFFF0F0F3);
  static const Color border = Color(0xFFE6E6EB);
  static const Color borderStrong = Color(0xFFD3D3DB);

  static const Color textPrimary = Color(0xFF13131A);
  static const Color textSecondary = Color(0xFF6C6C78);
  static const Color textTertiary = Color(0xFFA0A0AC);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Semantic — used only for status, never decoratively
  static const Color success = Color(0xFF17825A);
  static const Color successTint = Color(0xFFE7F5EF);

  static const Color warning = Color(0xFFB6660A);
  static const Color warningTint = Color(0xFFFBF0DF);

  static const Color urgent = Color(0xFFD8432B);
  static const Color urgentTint = Color(0xFFFBEAE7);

  static const Color info = Color(0xFF2F6FED);
  static const Color infoTint = Color(0xFFEAF1FE);
}
