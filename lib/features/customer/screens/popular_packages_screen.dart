import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/providers.dart';
import '../widgets/contact_help_footer.dart';
import 'package_seaters_screen.dart';

/// Fixed-rate outstation packages, reached from the Outstation trip type on
/// the search form. Reference content — nothing here books or holds a bus.
class PopularPackagesScreen extends ConsumerWidget {
  const PopularPackagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final locations = ref.watch(packagesProvider).items;
    return Scaffold(
      appBar: AppBar(title: const Text('Popular Packages')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
          children: [
            Text('Popular packages available from', style: textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final location in locations)
              packageRow(
                context,
                icon: Icons.place_outlined,
                label: location.city,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PackageSeatersScreen(location: location)),
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
            const ContactHelpFooter(message: 'If your location is not available, talk to us.'),
          ],
        ),
      ),
    );
  }
}

/// Shared drill-down row for the package screens, following the chevron row
/// used on the profile screen.
Widget packageRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  final textTheme = Theme.of(context).textTheme;
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: textTheme.bodyLarge)),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
        ],
      ),
    ),
  );
}
