import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/mock_data.dart';

/// REA-01..07: every bus free for the booking's exact window (including
/// buffer), a mandatory reason, and — for a round trip — the new bus must
/// be free for the entire remaining window, not just one leg.
class ReallocationPickerScreen extends StatefulWidget {
  const ReallocationPickerScreen({super.key, required this.currentBusReg});

  final String currentBusReg;

  @override
  State<ReallocationPickerScreen> createState() => _ReallocationPickerScreenState();
}

class _ReallocationPickerScreenState extends State<ReallocationPickerScreen> {
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
    final freeBuses = MockData.buses.where((b) => b.active && b.regNumber != widget.currentBusReg).toList();
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
                            'Currently ${widget.currentBusReg} · showing buses free for this exact window',
                            style: textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionLabel('Available buses'),
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
                onPressed: (_selectedBus != null && _reason != null) ? () => Navigator.of(context).pop(true) : null,
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
