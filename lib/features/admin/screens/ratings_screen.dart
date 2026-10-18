import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/async_body.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../../../data/rating_stats.dart';

/// BOOK-09: what customers said about their trips. Overall averages, the
/// buses that need attention first, and every rating with its comment.
class RatingsScreen extends ConsumerStatefulWidget {
  const RatingsScreen({super.key});

  @override
  ConsumerState<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends ConsumerState<RatingsScreen> {
  bool _lowOnly = false;

  static String _stars(double v) => v == 0 ? '—' : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bookings = {for (final b in ref.watch(bookingsProvider).items) b.id: b};
    final now = ref.watch(clockProvider)();
    return Scaffold(
      appBar: AppBar(title: const Text('Ratings')),
      body: SafeArea(
        child: AsyncBody<List<Rating>>(
          value: ref.watch(allRatingsProvider),
          builder: (all) {
            if (all.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text('No ratings yet. Customers are asked to rate a trip once it is completed.', textAlign: TextAlign.center, style: textTheme.bodyMedium),
                ),
              );
            }
            final stats = ratingStats(all);
            final byBus = ratingsByBus(all, bookings.values);
            final shown = _lowOnly ? all.where((r) => r.overall <= 2).toList() : all;
            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
              children: [
                Row(
                  children: [
                    Expanded(child: _tile(context, _stars(stats.overall), 'Overall')),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _tile(context, _stars(stats.bus), 'Bus')),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _tile(context, _stars(stats.driver), 'Driver')),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('From ${stats.count} ${stats.count == 1 ? 'rating' : 'ratings'}, out of 5.', style: textTheme.labelMedium),
                if (byBus.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const SectionLabel('By bus, lowest first'),
                  for (final b in byBus)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(child: Text(b.busReg, style: textTheme.bodyMedium)),
                          Text('${_stars(b.stats.overall)} · ${b.stats.count}', style: textTheme.labelMedium),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(child: Text('All ratings', style: textTheme.titleSmall)),
                    FilterChip(
                      label: const Text('1 or 2 stars only'),
                      selected: _lowOnly,
                      onSelected: (v) => setState(() => _lowOnly = v),
                      showCheckmark: false,
                      selectedColor: AppColors.primaryTint,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (shown.isEmpty) Text('No low ratings. Good.', style: textTheme.bodyMedium),
                for (final r in shown) ...[
                  Builder(builder: (context) {
                    final booking = bookings[r.bookingId];
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(booking?.reference ?? 'A booking', style: textTheme.titleSmall)),
                              Icon(Icons.star_rounded, size: 18, color: r.overall <= 2 ? AppColors.urgent : AppColors.accent),
                              const SizedBox(width: 2),
                              Text('${r.overall}', style: textTheme.titleSmall),
                            ],
                          ),
                          if (booking != null) Text('${booking.route} · ${booking.busReg}', style: textTheme.bodyMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Text('Bus ${r.bus} · Driver ${r.driver}', style: textTheme.labelMedium),
                          if (r.feedback.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text('"${r.feedback}"', style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          Text(AppDateFormat.ago(r.createdAt, now), style: textTheme.labelSmall),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, String value, String label) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.containerRadius, border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: textTheme.headlineSmall),
          Text(label, style: textTheme.labelMedium),
        ],
      ),
    );
  }
}
