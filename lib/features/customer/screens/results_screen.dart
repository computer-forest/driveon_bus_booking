import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/availability.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../widgets/bus_result_card.dart';
import 'bus_detail_screen.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, required this.criteria});

  /// What the customer asked for. Availability is applied against this, so
  /// only buses the admin actually opened for this window are listed.
  final SearchCriteria criteria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final buses = ref.watch(busesProvider);
    final bookings = ref.watch(bookingsProvider);
    final blackouts = ref.watch(blackoutsProvider);

    if (buses.isLoading || bookings.isLoading || blackouts.isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final results = searchBuses(
      criteria,
      buses: buses.items,
      bookings: bookings.items,
      blackouts: blackouts.items,
    );
    final summary = criteria.summary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          results.length == 1 ? '1 bus available' : '${results.length} buses available',
          style: textTheme.titleMedium,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: AppRadius.controlRadius,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        summary,
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? _emptyState(context)
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
                itemBuilder: (context, index) {
                  final bus = results[index];
                  final window = availabilityFor(bus, criteria.startsAt);
                  return _StaggeredEntrance(
                    index: index,
                    child: BusResultCard(
                      bus: bus,
                      windowLabel: AppDateFormat.timeRange(window.start, window.end),
                      onSelect: () => confirmBusSelection(
                        context,
                        ref,
                        bus: bus,
                        criteria: criteria,
                      ),
                      onViewDetails: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BusDetailScreen(bus: bus, criteria: criteria),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxxl, AppSpacing.xxl, AppSpacing.xxxl, 0),
      child: Column(
        children: [
          const Icon(Icons.event_busy_rounded, size: 40, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.lg),
          Text('No bus free for this window',
              style: textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Every bus is either booked, blocked, or outside its charter hours for the time you picked. Try a different time or date.',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          SecondaryButton(
            label: 'Change search',
            icon: Icons.tune_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Fades and slides each result card in with a small stagger, so the list
/// feels alive on first paint instead of popping in all at once.
class _StaggeredEntrance extends StatelessWidget {
  const _StaggeredEntrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + index * 80),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
