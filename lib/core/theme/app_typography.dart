import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Design tokens — type.
///
/// A single family (Inter) carries the whole app. Hierarchy comes from
/// weight, size and letter-spacing, not from mixing typefaces.
class AppTypography {
  AppTypography._();

  static TextTheme get textTheme => TextTheme(
        displaySmall: GoogleFonts.inter(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: AppColors.textPrimary,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 20,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13.5,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14.5,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12.5,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
          letterSpacing: 0.1,
        ),
      );

  /// Tabular-figure style for money, capacity and countdowns, so digits
  /// never jitter in width as they change.
  static TextStyle get numeric => GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
