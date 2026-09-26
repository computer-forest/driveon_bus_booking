import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/mock_data.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/booking_card.dart';
import 'admin_booking_detail_screen.dart';
import 'bus_calendar_screen.dart';
import 'bus_list_screen.dart';
import 'reports_screen.dart';

class BookingQueueScreen extends StatelessWidget {
  const BookingQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final holds = MockData.bookings.where((b) => b.isHold).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Booking queue')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${holds.length} requests waiting', style: textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: holds.isEmpty
                    ? Center(child: Text('No requests waiting.', style: textTheme.bodyMedium))
                    : ListView.builder(
                        itemCount: holds.length,
                        itemBuilder: (context, index) {
                          final booking = holds[index];
                          return BookingCard(
                            booking: booking,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => AdminBookingDetailScreen(booking: booking)),
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
