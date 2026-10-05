import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models.dart';
import '../widgets/contact_help_footer.dart';
import 'package_rates_screen.dart';
import 'popular_packages_screen.dart';

/// Seater classes available for packages leaving one city.
class PackageSeatersScreen extends StatelessWidget {
  const PackageSeatersScreen({super.key, required this.location});

  final PackageLocation location;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(location.city)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
          children: [
            Text('Packages from ${location.city}', style: textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final package in location.packages)
              packageRow(
                context,
                icon: Icons.airport_shuttle_outlined,
                label: package.seater,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PackageRatesScreen(location: location, package: package),
                  ),
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
