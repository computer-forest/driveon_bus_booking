import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/mock_data.dart';
import '../widgets/admin_bottom_nav.dart';
import 'booking_queue_screen.dart';
import 'bus_calendar_screen.dart';
import 'bus_form_screen.dart';
import 'reports_screen.dart';

/// BUS-01..07: bus master list. Reachable from the dashboard and from the
/// admin bottom nav's "Masters" tab.
class BusListScreen extends StatelessWidget {
  const BusListScreen({super.key});

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BookingQueueScreen()));
      case 1:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BusCalendarScreen()));
      case 3:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ReportsScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Buses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BusFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add bus'),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
          itemCount: MockData.buses.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            final bus = MockData.buses[i];
            return AppCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BusFormScreen(bus: bus))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(bus.regNumber, style: textTheme.titleSmall)),
                      StatusBadge(
                        label: bus.active ? 'Active' : 'Inactive',
                        tone: bus.active ? StatusTone.success : StatusTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${bus.vendorName} · ${bus.capacity} seater · ${bus.seatType}', style: textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (bus.ac) ...[const StatusBadge(label: 'AC'), const SizedBox(width: AppSpacing.sm)],
                      Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Text(bus.driverName, style: textTheme.labelMedium),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: AdminBottomNav(currentIndex: 2, onTap: (i) => _onNavTap(context, i)),
    );
  }
}
