import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../data/models.dart';

class QueueRow extends StatelessWidget {
  const QueueRow({super.key, required this.item, required this.onTap});

  final QueueItem item;
  final VoidCallback onTap;

  String get _clock {
    final m = (item.holdSecondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (item.holdSecondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _isUrgent => item.holdSecondsLeft < 300;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final urgentColor = _isUrgent ? AppColors.urgent : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.reference, style: textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '${item.customerName} · ${item.capacity} seater',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.route} · ${item.pickupWindow}',
                    style: textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
              decoration: BoxDecoration(
                color: _isUrgent ? AppColors.urgentTint : AppColors.surfaceAlt,
                borderRadius: AppRadius.tagRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 13, color: urgentColor),
                  const SizedBox(width: 4),
                  Text(
                    _clock,
                    style: textTheme.titleSmall?.copyWith(color: urgentColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
