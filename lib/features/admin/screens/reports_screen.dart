import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/mock_data.dart';
import '../widgets/admin_bottom_nav.dart';
import 'booking_queue_screen.dart';
import 'bus_calendar_screen.dart';
import 'bus_list_screen.dart';

/// ADM-12: bookings by status, advance/balance recorded, outstanding
/// payments, bus utilisation, vendor-wise counts, failed searches.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BookingQueueScreen()));
      case 1:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BusCalendarScreen()));
      case 2:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BusListScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
          children: [
            Text('Reports', style: textTheme.displaySmall?.copyWith(fontSize: 24)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _filterChip(context, 'Today', selected: true),
                const SizedBox(width: AppSpacing.sm),
                _filterChip(context, 'This week', selected: false),
                const SizedBox(width: AppSpacing.sm),
                _filterChip(context, 'This month', selected: false),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.5,
              children: MockData.reportMetrics.map((m) {
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
                      if (m.sublabel != null) Text(m.sublabel!, style: textTheme.labelSmall),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Vendor-wise bookings', style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            for (final v in MockData.vendors) ...[
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
                          value: v.busCount / 8,
                          backgroundColor: AppColors.surfaceAlt,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('${v.busCount}', style: textTheme.labelMedium),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: AdminBottomNav(currentIndex: 3, onTap: (i) => _onNavTap(context, i)),
    );
  }

  Widget _filterChip(BuildContext context, String label, {required bool selected}) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: AppRadius.controlRadius,
        border: Border.all(color: selected ? AppColors.primary : AppColors.border),
      ),
      child: Text(
        label,
        style: textTheme.labelMedium?.copyWith(color: selected ? AppColors.onPrimary : AppColors.textPrimary),
      ),
    );
  }
}
