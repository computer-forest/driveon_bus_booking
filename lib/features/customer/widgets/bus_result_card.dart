import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models.dart';
import '../../shared/bus_photo.dart';

class BusResultCard extends StatelessWidget {
  const BusResultCard({
    super.key,
    required this.bus,
    required this.windowLabel,
    required this.onSelect,
    required this.onViewDetails,
  });

  final BusRecord bus;

  /// The charter window the admin set for the day being searched.
  final String windowLabel;
  final VoidCallback onSelect;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onViewDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${bus.capacity}',
                      style: textTheme.displaySmall?.copyWith(fontSize: 26)),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('seater', style: textTheme.bodyMedium),
                  ),
                ],
              ),
              const StatusBadge(label: 'Available', tone: StatusTone.success),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (bus.cover != null)
            // The small thumbnail, not the full picture: a list of buses must stay light.
            ClipRRect(
              borderRadius: AppRadius.tagRadius,
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: BusPhotoView(
                    key: const Key('bus-card-cover'),
                    url: bus.cover!.thumbUrl,
                    decodeWidth: 360),
              ),
            )
          else
            Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Container(
                    height: 56,
                    margin: EdgeInsets.only(right: i == 2 ? 0 : AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.tagRadius,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      [
                        Icons.ac_unit_rounded,
                        Icons.event_seat_rounded,
                        Icons.luggage_rounded
                      ][i],
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (bus.ac) ...[
                const StatusBadge(label: 'AC'),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(bus.seatType,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text('Available $windowLabel',
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SecondaryButton(label: 'Select this bus', onPressed: onSelect),
        ],
      ),
    );
  }
}
