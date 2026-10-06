import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../shared/notification_list.dart';
import '../widgets/customer_bottom_nav.dart';
import 'booking_detail_screen.dart';
import 'home_search_screen.dart';
import 'my_bookings_screen.dart';

/// NOTIF-04: the customer's in-app inbox, mirroring every push, with read
/// state and a link into the booking each one is about.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _onNavTap(BuildContext context, int index) {
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeSearchScreen()),
        (route) => false,
      );
    } else if (index == 1) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notifications', style: textTheme.displaySmall?.copyWith(fontSize: 24)),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: NotificationList(
                  onOpenBooking: (booking) => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: booking)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomerBottomNav(currentIndex: 2, onTap: (i) => _onNavTap(context, i)),
    );
  }
}
