import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../data/mock_data.dart';
import '../../../data/models.dart';
import '../widgets/admin_bottom_nav.dart';
import 'audit_log_screen.dart';
import 'blackout_maintenance_screen.dart';
import 'booking_queue_screen.dart';
import 'bus_calendar_screen.dart';
import 'bus_list_screen.dart';
import 'masters_config_screen.dart';
import 'notification_templates_screen.dart';
import 'reports_screen.dart';
import 'vendor_list_screen.dart';

/// The Admin landing screen (BRD 9.1: "dashboard"), separate from the
/// booking queue — a quick operational snapshot plus shortcuts into every
/// Admin area, since the bottom nav only carries the four busiest ones.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
          children: [
            Text('Good morning, Priya', style: textTheme.displaySmall?.copyWith(fontSize: 24)),
            const SizedBox(height: 4),
            Text('Operations console · Neeta Travels fleet', style: textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(gradient: AppGradients.hero, borderRadius: AppRadius.containerRadius),
              child: Row(
                children: [
                  const Icon(Icons.dns_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      '${MockData.bookings.where((b) => b.isHold).length} bookings waiting in the queue',
                      style: textTheme.titleSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BookingQueueScreen()),
                    ),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Today'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.5,
              children: MockData.reportMetrics.take(4).map((m) => _metricTile(context, m)).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Manage'),
            _shortcut(context, Icons.storefront_outlined, 'Vendors', const VendorListScreen()),
            _shortcut(context, Icons.directions_bus_filled_outlined, 'Buses', const BusListScreen()),
            _shortcut(context, Icons.block_rounded, 'Blackout & maintenance', const BlackoutMaintenanceScreen()),
            _shortcut(context, Icons.tune_rounded, 'Masters & configuration', const MastersConfigScreen()),
            _shortcut(context, Icons.mark_email_unread_outlined, 'Notification & email templates', const NotificationTemplatesScreen()),
            _shortcut(context, Icons.receipt_long_outlined, 'Audit log', const AuditLogScreen()),
          ],
        ),
      ),
      bottomNavigationBar: AdminBottomNav(
        currentIndex: -1,
        onTap: (i) {
          switch (i) {
            case 0:
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookingQueueScreen()));
            case 1:
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BusCalendarScreen()));
            case 2:
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BusListScreen()));
            case 3:
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportsScreen()));
          }
        },
      ),
    );
  }

  Widget _metricTile(BuildContext context, ReportMetric m) {
    final textTheme = Theme.of(context).textTheme;
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
        ],
      ),
    );
  }

  Widget _shortcut(BuildContext context, IconData icon, String label, Widget screen) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
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
}
