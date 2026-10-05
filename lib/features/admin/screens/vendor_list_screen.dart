import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/providers.dart';
import 'vendor_form_screen.dart';

/// VEN-02: vendor list with search, edit and deactivate.
class VendorListScreen extends ConsumerWidget {
  const VendorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final vendors = ref.watch(vendorsProvider).items;
    final buses = ref.watch(busesProvider).items;
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
          itemCount: vendors.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            final v = vendors[i];
            final busCount = buses.where((b) => b.vendorId == v.id).length;
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
                        Text(busCount == 1 ? '1 bus' : '$busCount buses', style: textTheme.labelSmall),
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
