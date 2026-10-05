import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/stage_badge.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';

/// The one place a booking's full detail is readable without tapping
/// anything — used on both the booking queue and the calendar's trip list.
class BookingCard extends ConsumerWidget {
  const BookingCard({super.key, required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider)();
    final secondsLeft = booking.holdSecondsLeft(now);
    final holdUrgent = secondsLeft < 300;
    final clock = '${(secondsLeft ~/ 60).toString().padLeft(2, '0')}:'
        '${(secondsLeft % 60).toString().padLeft(2, '0')}';
    final bus = ref.watch(busesProvider).items.where((b) => b.id == booking.busId).firstOrNull;
    final driverName = bus?.driverName ?? 'Unassigned';
    final moneyLine = booking.isHold
        ? 'Cost not yet confirmed'
        : booking.balanceDue > 0
            ? '${AppMoneyFormat.rupees(booking.totalFare)} · ${AppMoneyFormat.rupees(booking.balanceDue)} due'
            : '${AppMoneyFormat.rupees(booking.totalFare)} · Paid in full';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(booking.reference, style: textTheme.titleSmall)),
                if (booking.isHold)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
                    decoration: BoxDecoration(
                      color: holdUrgent ? AppColors.urgentTint : AppColors.surfaceAlt,
                      borderRadius: AppRadius.tagRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 13, color: holdUrgent ? AppColors.urgent : AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(clock,
                            style: textTheme.titleSmall
                                ?.copyWith(color: holdUrgent ? AppColors.urgent : AppColors.textSecondary)),
                      ],
                    ),
                  )
                else
                  StageBadge(booking.stage),
              ],
            ),
            const SizedBox(height: 2),
            Text('${booking.customerName} · ${booking.capacity} seater', style: textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(booking.route, style: textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(
              '${AppDateFormat.timeRange(TimeOfDay.fromDateTime(booking.start), TimeOfDay.fromDateTime(booking.end))} · '
              '${booking.busReg} · $driverName',
              style: textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Text(moneyLine, style: AppTypography.numeric.copyWith(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
