import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../widgets/contact_help_footer.dart';

/// Fixed package rates for one city and seater class. No table primitive
/// exists in this app, so the chart is built the way the payment ledger is:
/// an AppCard of rows separated by hairlines.
class PackageRatesScreen extends ConsumerWidget {
  const PackageRatesScreen(
      {super.key, required this.location, required this.package});

  final PackageLocation location;
  final SeaterPackage package;

  /// Fixed so both rate columns stay aligned no matter how the trip name wraps.
  static const _rateColumnWidth = 74.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final note = ref.watch(appConfigProvider).config.packageNote.trim();
    return Scaffold(
      appBar: AppBar(title: Text(location.city)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
          children: [
            Text(package.seater, style: textTheme.titleMedium),
            const SizedBox(height: 2),
            Text('Return packages from ${location.city}',
                style: textTheme.bodyMedium),
            if (package.sampleRates) ...[
              const SizedBox(height: AppSpacing.md),
              const StatusBadge(
                  label: 'Sample rates', tone: StatusTone.warning),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Indicative only — confirm the fare with us before you plan around it.',
                style: textTheme.labelMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                children: [
                  _headerRow(context),
                  const HairlineDivider(),
                  for (final trip in package.trips) ...[
                    _tripRow(context, trip),
                    if (trip != package.trips.last) const HairlineDivider(),
                  ],
                ],
              ),
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(note, style: textTheme.labelMedium),
            ],
            const SizedBox(height: AppSpacing.xxl),
            const ContactHelpFooter(
                message: 'If your location is not available, talk to us.'),
          ],
        ),
      ),
    );
  }

  Widget _headerRow(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text('Trip', style: textTheme.labelMedium)),
        SizedBox(
          width: _rateColumnWidth,
          child: Text('1 day',
              style: textTheme.labelMedium, textAlign: TextAlign.right),
        ),
        SizedBox(
          width: _rateColumnWidth,
          child: Text('2 days',
              style: textTheme.labelMedium, textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _tripRow(BuildContext context, PackageTrip trip) {
    final textTheme = Theme.of(context).textTheme;
    final rateStyle = AppTypography.numeric.copyWith(fontSize: 13.5);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text('${location.city} to ${trip.destination} & return',
              style: textTheme.bodyLarge),
        ),
        SizedBox(
          width: _rateColumnWidth,
          child: Text(
            AppMoneyFormat.rupees(trip.oneDayRate),
            style: rateStyle,
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: _rateColumnWidth,
          child: Text(
            AppMoneyFormat.rupees(trip.twoDayRate),
            style: rateStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
