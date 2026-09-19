import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/date_time_field.dart';
import '../../../data/models.dart';
import 'driver_assignment_screen.dart';

/// DRV-01: name, DOB, licence number/expiry, address, phone, photo, with
/// vendor selected. DRV-02 (assignment to a bus) is a separate step,
/// reached from here once the driver record exists.
class DriverFormScreen extends StatefulWidget {
  const DriverFormScreen({super.key, this.driver});

  final DriverRecord? driver;

  @override
  State<DriverFormScreen> createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends State<DriverFormScreen> {
  DateTime _dob = DateTime(1990, 1, 1);

  bool get _isEdit => widget.driver != null;

  @override
  Widget build(BuildContext context) {
    final d = widget.driver;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit driver' : 'Add driver')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                child: const Icon(Icons.add_a_photo_outlined, color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            LabeledField(label: 'Full name', initialValue: d?.name),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(label: 'Phone', initialValue: d?.phone, keyboardType: TextInputType.phone),
            const SizedBox(height: AppSpacing.lg),
            DateField(label: 'Date of birth', value: _dob, onChanged: (v) => setState(() => _dob = v)),
            const SizedBox(height: AppSpacing.lg),
            const LabeledField(label: 'Address'),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(label: 'Licence number', initialValue: d?.licenceNumber),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(label: 'Licence expiry', initialValue: d?.licenceExpiry, suffixIcon: Icons.calendar_today_outlined),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(label: 'Vendor', initialValue: d?.vendorName),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(label: _isEdit ? 'Save changes' : 'Add driver', onPressed: () => Navigator.of(context).pop()),
            if (_isEdit) ...[
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: d!.assignedBus != null ? 'Reassign bus' : 'Assign to a bus',
                icon: Icons.directions_bus_filled_outlined,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DriverAssignmentScreen(driver: d)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
