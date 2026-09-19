import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/mock_data.dart';
import 'vendor_form_screen.dart';

/// VEN-02: vendor list with search, edit and deactivate.
class VendorListScreen extends StatelessWidget {
  const VendorListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Vendors')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VendorFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add vendor'),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
          itemCount: MockData.vendors.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            final v = MockData.vendors[i];
            return AppCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VendorFormScreen(vendor: v))),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                    child: const Icon(Icons.storefront_rounded, size: 18, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.name, style: textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text('${v.contactPerson} · ${v.phone}', style: textTheme.bodyMedium),
                        Text('${v.busCount} buses', style: textTheme.labelSmall),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: v.active ? 'Active' : 'Inactive',
                    tone: v.active ? StatusTone.success : StatusTone.neutral,
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
