import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/providers.dart';
import '../../../data/reports.dart';
import '../widgets/admin_bottom_nav.dart';
import 'booking_queue_screen.dart';
import 'bus_calendar_screen.dart';
import 'bus_list_screen.dart';

/// ADM-12: requests and confirmations, money collected, outstanding
/// payments, fleet utilisation, vendor-wise bookings, failed searches, all
/// worked out from the real records for the chosen period.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.today;

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const BookingQueueScreen()));
      case 1:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const BusCalendarScreen()));
      case 2:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const BusListScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final report = ref.watch(reportProvider(_period));
    final metrics = report.metrics;
    final vendors = report.vendors;
    final maxBookings = vendors.fold<int>(1, (m, v) => v.bookings > m ? v.bookings : m);
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final p in ReportPeriod.values) _filterChip(context, p),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.3,
              children: metrics.map((m) {
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.containerRadius,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(m.value, style: textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text(m.label, style: textTheme.labelMedium),
                      if (m.sublabel != null)
                        Text(m.sublabel!, style: textTheme.labelSmall),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Vendor-wise bookings', style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            for (final v in vendors)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(child: Text(v.name, style: textTheme.bodyMedium)),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 120,
                        height: 8,
                        child: LinearProgressIndicator(
                          value: v.bookings / maxBookings,
                          backgroundColor: AppColors.surfaceAlt,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('${v.bookings}', style: textTheme.labelMedium),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar:
          AdminBottomNav(currentIndex: 3, onTap: (i) => _onNavTap(context, i)),
    );
  }

  Widget _filterChip(BuildContext context, ReportPeriod period) {
    final textTheme = Theme.of(context).textTheme;
    final selected = period == _period;
    return GestureDetector(
      onTap: () => setState(() => _period = period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: AppRadius.controlRadius,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          period.label,
          style: textTheme.labelMedium?.copyWith(color: selected ? AppColors.onPrimary : AppColors.textPrimary),
        ),
      ),
    );
  }
}
