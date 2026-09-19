import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/mock_data.dart';
import '../widgets/bus_result_card.dart';
import 'bus_detail_screen.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, this.summary});

  /// Route + date/time line, formatted by the search screen from the
  /// values the customer actually picked. Falls back to sample copy when
  /// the screen is opened directly (e.g. in previews).
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final results = MockData.busResults;

    return Scaffold(
      appBar: AppBar(
        title: Text('${results.length} buses available', style: textTheme.titleMedium),
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
                        summary ?? 'Thane → Mahabaleshwar · 14 Sep, 6:00 AM',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
                itemBuilder: (context, index) {
                  final bus = results[index];
                  return _StaggeredEntrance(
                    index: index,
                    child: BusResultCard(
                      bus: bus,
                      onSelect: () => confirmBusSelection(
                        context,
                        bus: bus,
                        routeSummary: summary ?? 'Thane → Mahabaleshwar · 14 Sep, 6:00 AM',
                      ),
                      onViewDetails: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BusDetailScreen(
                              bus: bus,
                              routeSummary: summary ?? 'Thane → Mahabaleshwar · 14 Sep, 6:00 AM',
                            ),
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
