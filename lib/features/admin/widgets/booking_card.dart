import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/mock_data.dart';
import '../../../data/models.dart';

String busLabelFor(String reg) {
  for (final bus in MockData.buses) {
    if (bus.regNumber == reg) return bus.regNumber;
  }
  return reg;
}

String driverNameFor(String reg) {
  for (final bus in MockData.buses) {
    if (bus.regNumber == reg) return bus.driverName;
  }
  return 'Unassigned';
}

(String, StatusTone) stageDisplay(BookingStage stage) {
  switch (stage) {
    case BookingStage.requested:
      return ('Hold', StatusTone.warning);
    case BookingStage.confirmed:
      return ('Confirmed', StatusTone.info);
    case BookingStage.inTrip:
      return ('In trip', StatusTone.warning);
    case BookingStage.completed:
      return ('Completed', StatusTone.warning);
    case BookingStage.settled:
      return ('Settled', StatusTone.success);
  }
}

/// The one place a booking's full detail is readable without tapping
/// anything — used on both the booking queue and the calendar's trip list.
class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  String get _clock {
    final m = (booking.holdSecondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (booking.holdSecondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _holdUrgent => booking.holdSecondsLeft < 300;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (stageLabel, stageTone) = stageDisplay(booking.stage);
    final moneyLine = booking.isHold
        ? 'Cost not yet confirmed'
        : booking.balanceDue > 0
            ? '₹${booking.totalFare} · ₹${booking.balanceDue} due'
            : '₹${booking.totalFare} · Paid in full';

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
                      color: _holdUrgent ? AppColors.urgentTint : AppColors.surfaceAlt,
                      borderRadius: AppRadius.tagRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 13, color: _holdUrgent ? AppColors.urgent : AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(_clock,
                            style: textTheme.titleSmall
                                ?.copyWith(color: _holdUrgent ? AppColors.urgent : AppColors.textSecondary)),
                      ],
                    ),
                  )
                else
                  StatusBadge(label: stageLabel, tone: stageTone),
              ],
            ),
            const SizedBox(height: 2),
            Text('${booking.customerName} · ${booking.capacity} seater', style: textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(booking.route, style: textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(
              '${AppDateFormat.timeRange(TimeOfDay.fromDateTime(booking.start), TimeOfDay.fromDateTime(booking.end))} · '
              '${busLabelFor(booking.busReg)} · ${driverNameFor(booking.busReg)}',
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
