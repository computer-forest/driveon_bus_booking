import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/availability.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';

/// REA-01..07: every bus free for the booking's exact window (including
/// buffer), a mandatory reason, and — for a round trip — the new bus must
/// be free for the entire remaining window, not just one leg.
///
/// Pops the chosen [BusRecord], or nothing if the admin backs out.
class ReallocationPickerScreen extends ConsumerStatefulWidget {
  const ReallocationPickerScreen({
    super.key,
    required this.currentBusId,
    required this.start,
    required this.end,
  });

  final String currentBusId;
  final DateTime start;
  final DateTime end;

  @override
  ConsumerState<ReallocationPickerScreen> createState() => _ReallocationPickerScreenState();
}

class _ReallocationPickerScreenState extends ConsumerState<ReallocationPickerScreen> {
  String? _selectedBus;
  String? _reason;
  bool _changeCost = false;

  static const _reasons = [
    'Selected bus at another location',
    'Vendor needs the bus elsewhere',
    'Mechanical issue',
    'Customer requested a different capacity',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bookings = ref.watch(bookingsProvider).items;
    final blackouts = ref.watch(blackoutsProvider).items;
    final allBuses = ref.watch(busesProvider).items;
    final current = allBuses.where((b) => b.id == widget.currentBusId).firstOrNull;
    final freeBuses = allBuses
        .where((b) =>
            b.id != widget.currentBusId &&
            isBusFree(b, widget.start, widget.end, bookings: bookings, blackouts: blackouts))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Reallocate bus')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.controlRadius),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_bus_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Currently ${current?.regNumber ?? 'unassigned'} · free for '
                            '${AppDateFormat.dayMonth(widget.start)}, '
                            '${AppDateFormat.timeRange(TimeOfDay.fromDateTime(widget.start), TimeOfDay.fromDateTime(widget.end))}',
                            style: textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionLabel('Available buses'),
                  if (freeBuses.isEmpty)
                    Text('No other bus is free for this window.', style: textTheme.bodyMedium),
                  for (final bus in freeBuses) ...[
                    _busTile(bus.regNumber, '${bus.vendorName} · ${bus.capacity} seater · ${bus.seatType}'),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const SectionLabel('Reason for reallocation'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _reasons.map((r) {
                      final selected = _reason == r;
                      return ChoiceChip(
                        label: Text(r),
                        selected: selected,
                        onSelected: (_) => setState(() => _reason = r),
                        selectedColor: AppColors.primary,
                        labelStyle: textTheme.labelMedium
                            ?.copyWith(color: selected ? AppColors.onPrimary : AppColors.textPrimary),
                        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cost changes with this bus', style: textTheme.titleSmall),
                              Text('Edit the confirmed fare as part of this action.', style: textTheme.labelMedium),
                            ],
                          ),
                        ),
                        Switch(
                          value: _changeCost,
                          activeThumbColor: AppColors.primary,
                          onChanged: (v) => setState(() => _changeCost = v),
                        ),
                      ],
                    ),
                  ),
                  if (_changeCost) ...[
                    const SizedBox(height: AppSpacing.md),
                    const LabeledField(label: 'Revised total fare (₹)', keyboardType: TextInputType.number),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: PrimaryButton(
                label: 'Confirm reallocation',
                onPressed: (_selectedBus != null && _reason != null)
                    ? () => Navigator.of(context).pop(freeBuses.firstWhere((b) => b.regNumber == _selectedBus))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _busTile(String reg, String subtitle) {
    final selected = _selectedBus == reg;
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => setState(() => _selectedBus = reg),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: selected ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reg, style: textTheme.titleSmall),
                Text(subtitle, style: textTheme.bodyMedium),
              ],
            ),
          ),
          const StatusBadge(label: 'Free', tone: StatusTone.success),
        ],
      ),
    );
  }
}
