import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../shared/notification_list.dart';
import 'admin_booking_detail_screen.dart';

/// Staff's inbox: new requests, holds about to run out, cancellation requests.
class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
          child: NotificationList(
            onOpenBooking: (booking) => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AdminBookingDetailScreen(booking: booking)),
            ),
          ),
        ),
      ),
    );
  }
}
