import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/date_time_field.dart';

/// CAN-01..05: only Admin can cancel; requires a reason and releases the
/// block immediately, then records any offline refund against the booking.
class CancelRefundScreen extends StatefulWidget {
  const CancelRefundScreen({super.key, required this.reference});

  final String reference;

  @override
  State<CancelRefundScreen> createState() => _CancelRefundScreenState();
}

class _CancelRefundScreenState extends State<CancelRefundScreen> {
  String? _reason;
  bool _refundApplicable = false;
  DateTime _refundDate = DateTime(2026, 9, 11);
  String _mode = 'UPI';

  static const _reasons = [
    'Customer requested',
    'Bus unavailable',
    'Duplicate booking',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('Cancel ${widget.reference}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: AppColors.urgentTint, borderRadius: AppRadius.controlRadius),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.urgent, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'This releases the bus block immediately and notifies the customer.',
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.urgent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Reason for cancellation'),
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
                  labelStyle: textTheme.labelMedium?.copyWith(color: selected ? AppColors.onPrimary : AppColors.textPrimary),
                  side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Refund applicable', style: textTheme.titleSmall),
                        Text('Refunds happen outside the app — record what was paid back.', style: textTheme.labelMedium),
                      ],
                    ),
                  ),
                  Switch(
                    value: _refundApplicable,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => setState(() => _refundApplicable = v),
                  ),
                ],
              ),
            ),
            if (_refundApplicable) ...[
              const SizedBox(height: AppSpacing.lg),
              const LabeledField(label: 'Refund amount (₹)', keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _mode,
                      decoration: const InputDecoration(labelText: 'Mode'),
                      items: ['UPI', 'Bank transfer', 'Cash'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => setState(() => _mode = v ?? _mode),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: DateField(label: 'Date', value: _refundDate, onChanged: (v) => setState(() => _refundDate = v))),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const LabeledField(label: 'Reference'),
            ],
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _reason == null ? null : () => Navigator.of(context).pop(true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.urgent,
                  side: const BorderSide(color: AppColors.urgent),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Cancel booking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
