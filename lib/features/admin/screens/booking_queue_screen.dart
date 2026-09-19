import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/mock_data.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/queue_row.dart';
import 'admin_booking_detail_screen.dart';
import 'bus_calendar_screen.dart';
import 'bus_list_screen.dart';
import 'reports_screen.dart';

class BookingQueueScreen extends StatelessWidget {
  const BookingQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final queue = MockData.queue;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Booking queue', style: textTheme.displaySmall?.copyWith(fontSize: 24)),
              const SizedBox(height: 4),
              Text('${queue.length} requests waiting', style: textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView.builder(
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    return QueueRow(
                      item: item,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AdminBookingDetailScreen()),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AdminBottomNav(
        currentIndex: 0,
        onTap: (i) {
          switch (i) {
            case 1:
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BusCalendarScreen()));
            case 2:
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BusListScreen()));
            case 3:
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ReportsScreen()));
          }
        },
      ),
    );
  }
}
