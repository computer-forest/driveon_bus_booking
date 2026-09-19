import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../data/mock_data.dart';
import '../../../data/models.dart';

/// BUS-01: vendor selection is mandatory before anything else on this
/// form — a bus cannot exist without a vendor.
class BusFormScreen extends StatefulWidget {
  const BusFormScreen({super.key, this.bus});

  final BusRecord? bus;

  @override
  State<BusFormScreen> createState() => _BusFormScreenState();
}

class _BusFormScreenState extends State<BusFormScreen> {
  static const _capacities = [17, 20, 27, 30, 35, 40];
  static const _seatTypes = ['Pushback', 'Highback', 'Basic'];

  late String? _vendor = widget.bus?.vendorName;
  late int _capacity = widget.bus?.capacity ?? 20;
  late String _seatType = widget.bus?.seatType.split(' ').first ?? 'Pushback';
  late bool _ac = widget.bus?.ac ?? true;
  late bool _active = widget.bus?.active ?? true;

  bool get _isEdit => widget.bus != null;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit bus' : 'Add bus')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          children: [
            const SectionLabel('Vendor'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.controlRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _vendor,
                  isExpanded: true,
                  hint: const Text('Select vendor (required)'),
                  items: MockData.vendors
                      .where((v) => v.active)
                      .map((v) => DropdownMenuItem(value: v.name, child: Text(v.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _vendor = v),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(label: 'Registration number', initialValue: widget.bus?.regNumber, hint: 'e.g. MH-04-BT-7781'),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(label: 'Base city', initialValue: widget.bus?.baseCity),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Capacity'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _capacities.map((c) {
                final selected = c == _capacity;
                return ChoiceChip(
                  label: Text('$c'),
                  selected: selected,
                  onSelected: (_) => setState(() => _capacity = c),
                  selectedColor: AppColors.primary,
                  labelStyle: textTheme.labelMedium?.copyWith(color: selected ? AppColors.onPrimary : AppColors.textPrimary),
                  side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Seat type'),
            Wrap(
              spacing: AppSpacing.sm,
              children: _seatTypes.map((s) {
                final selected = s == _seatType;
                return ChoiceChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: (_) => setState(() => _seatType = s),
                  selectedColor: AppColors.primary,
                  labelStyle: textTheme.labelMedium?.copyWith(color: selected ? AppColors.onPrimary : AppColors.textPrimary),
                  side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Row(
                children: [
                  Expanded(child: Text('Air conditioned', style: textTheme.titleSmall)),
                  Switch(value: _ac, activeThumbColor: AppColors.primary, onChanged: (v) => setState(() => _ac = v)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const LabeledField(label: 'GPS link', hint: 'https://...'),
            const SizedBox(height: AppSpacing.lg),
            const SectionLabel('Photographs (up to 4)'),
            Row(
              children: List.generate(4, (i) {
                return Padding(
                  padding: EdgeInsets.only(right: i == 3 ? 0 : AppSpacing.sm),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.controlRadius,
                      border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined, size: 20, color: AppColors.textTertiary),
                  ),
                );
              }),
            ),
            if (_isEdit) ...[
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active', style: textTheme.titleSmall),
                          Text('Deactivating removes this bus from search immediately.', style: textTheme.labelMedium),
                        ],
                      ),
                    ),
                    Switch(value: _active, activeThumbColor: AppColors.primary, onChanged: (v) => setState(() => _active = v)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: _isEdit ? 'Save changes' : 'Add bus',
              onPressed: _vendor == null ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
