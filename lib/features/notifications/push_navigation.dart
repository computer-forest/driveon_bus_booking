import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/nested_shell.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../admin/screens/admin_booking_detail_screen.dart';
import '../admin/screens/admin_notifications_screen.dart';
import '../customer/screens/booking_detail_screen.dart';
import '../customer/screens/notifications_screen.dart';
import 'push_service.dart';

/// Opens what a tapped notification was about: the booking, or the inbox when
/// it was not about one or the booking cannot be found. Returns false when
/// there was nowhere to open it (signed out, or no screen is up yet), so the
/// caller can try again.
Future<bool> openPushTap(WidgetRef ref, PushTap tap) async {
  final navigator = NestedNavigatorShell.activeNavigator;
  final user = ref.read(authStateProvider).value;
  if (navigator == null || user == null || !user.onboarded) return false;

  Booking? booking;
  final id = tap.bookingId;
  if (id != null) {
    try {
      // A customer's list holds only their own bookings, staff's holds all;
      // read it once (a stream can be paused when nothing is watching it).
      final all = await ref.read(bookingRepositoryProvider).watchAll().first.timeout(const Duration(seconds: 8));
      booking = all.where((b) => b.id == id).firstOrNull;
      // A customer is only ever taken to their own booking, whatever the list holds.
      if (booking != null && !user.isAdmin && booking.customerId != user.id) booking = null;
    } on TimeoutException {
      booking = null;
    }
  }
  if (!navigator.mounted) return false;

  final Widget screen;
  if (booking != null) {
    screen = user.isAdmin ? AdminBookingDetailScreen(booking: booking) : BookingDetailScreen(booking: booking);
  } else {
    screen = user.isAdmin ? const AdminNotificationsScreen() : const NotificationsScreen();
  }
  unawaited(navigator.push(MaterialPageRoute(builder: (_) => screen)));
  return true;
}
