import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../data/models.dart';

/// VEN-01/VEN-02: register or edit a vendor. A vendor with active buses
/// cannot be deleted — only deactivated.
class VendorFormScreen extends StatefulWidget {
  const VendorFormScreen({super.key, this.vendor});

  final Vendor? vendor;

  @override
  State<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends State<VendorFormScreen> {
  late bool _active = widget.vendor?.active ?? true;

  bool get _isEdit => widget.vendor != null;

  @override
  Widget build(BuildContext context) {
    final v = widget.vendor;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit vendor' : 'Add vendor')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          children: [
            LabeledField(label: 'Trading name', initialValue: v?.name, hint: 'e.g. Neeta Travels'),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(label: 'Contact person', initialValue: v?.contactPerson),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(label: 'Phone', initialValue: v?.phone, keyboardType: TextInputType.phone),
            const SizedBox(height: AppSpacing.lg),
            const LabeledField(label: 'Email', hint: 'accounts@vendor.example', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: AppSpacing.lg),
            const LabeledField(label: 'Address', hint: 'Registered address'),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: const [
                Expanded(child: LabeledField(label: 'PAN (optional)')),
                SizedBox(width: AppSpacing.md),
                Expanded(child: LabeledField(label: 'GST (optional)')),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_isEdit)
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active', style: textTheme.titleSmall),
                          Text(
                            'Deactivating removes their buses from search but leaves existing bookings untouched.',
                            style: textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                    Switch(value: _active, activeThumbColor: AppColors.primary, onChanged: (v) => setState(() => _active = v)),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: _isEdit ? 'Save changes' : 'Add vendor',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
