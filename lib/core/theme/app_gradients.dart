import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Design tokens — gradients.
///
/// A small, fixed set of brand gradients. Used only on hero surfaces
/// (primary action, hero headers, the held-bus banner) — never applied
/// broadly, so the app keeps its flat, high-contrast base.
class AppGradients {
  AppGradients._();

  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primarySoft, AppColors.primary],
  );

  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryDeep],
  );

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFA35C), AppColors.accent],
  );
}
