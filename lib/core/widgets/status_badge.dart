import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

enum StatusTone { neutral, success, warning, urgent, info }

class _ToneColors {
  const _ToneColors(this.fg, this.bg);
  final Color fg;
  final Color bg;
}

/// A small, tinted status marker with a matching dot for quick scanning.
/// Deliberately not a pill shape — a subtle tinted rounded-rect reads as a
/// status field, not a button.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.tone = StatusTone.neutral});

  final String label;
  final StatusTone tone;

  _ToneColors get _colors {
    switch (tone) {
      case StatusTone.success:
        return const _ToneColors(AppColors.success, AppColors.successTint);
      case StatusTone.warning:
        return const _ToneColors(AppColors.warning, AppColors.warningTint);
      case StatusTone.urgent:
        return const _ToneColors(AppColors.urgent, AppColors.urgentTint);
      case StatusTone.info:
        return const _ToneColors(AppColors.info, AppColors.infoTint);
      case StatusTone.neutral:
        return const _ToneColors(AppColors.textSecondary, AppColors.surfaceAlt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
      decoration: BoxDecoration(color: c.bg, borderRadius: AppRadius.tagRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.fg),
          ),
        ],
      ),
    );
  }
}
