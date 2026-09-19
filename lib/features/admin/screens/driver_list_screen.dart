import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/mock_data.dart';
import 'driver_form_screen.dart';

/// DRV-01/02: drivers registered independently of buses, then assigned.
class DriverListScreen extends StatelessWidget {
  const DriverListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Drivers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DriverFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add driver'),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
          itemCount: MockData.drivers.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            final d = MockData.drivers[i];
            final assigned = d.assignedBus != null;
            return AppCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DriverFormScreen(driver: d))),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                    child: const Icon(Icons.person_rounded, size: 18, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name, style: textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text('${d.phone} · ${d.vendorName}', style: textTheme.bodyMedium),
                        Text('Licence expires ${d.licenceExpiry}', style: textTheme.labelSmall),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: assigned ? d.assignedBus! : 'Unassigned',
                    tone: assigned ? StatusTone.info : StatusTone.neutral,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
