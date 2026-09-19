import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/mock_data.dart';
import '../../../data/models.dart';

/// DRV-02: assign a registered driver to a bus. A bus has one current
/// driver at a time — picking a bus that already has one shows the swap.
class DriverAssignmentScreen extends StatefulWidget {
  const DriverAssignmentScreen({super.key, required this.driver});

  final DriverRecord driver;

  @override
  State<DriverAssignmentScreen> createState() => _DriverAssignmentScreenState();
}

class _DriverAssignmentScreenState extends State<DriverAssignmentScreen> {
  String? _selectedBus;

  @override
  void initState() {
    super.initState();
    _selectedBus = widget.driver.assignedBus;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('Assign ${widget.driver.name}')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
                itemCount: MockData.buses.where((b) => b.active).length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) {
                  final bus = MockData.buses.where((b) => b.active).toList()[i];
                  final selected = _selectedBus == bus.regNumber;
                  final hasOtherDriver = bus.driverName != 'Unassigned' && bus.driverName != widget.driver.name;
                  return AppCard(
                    onTap: () => setState(() => _selectedBus = bus.regNumber),
                    padding: const EdgeInsets.all(AppSpacing.md),
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
                              Text(bus.regNumber, style: textTheme.titleSmall),
                              Text('${bus.vendorName} · ${bus.capacity} seater', style: textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        if (hasOtherDriver) StatusBadge(label: 'Has ${bus.driverName}', tone: StatusTone.warning),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: PrimaryButton(
                label: 'Confirm assignment',
                onPressed: _selectedBus == null ? null : () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
