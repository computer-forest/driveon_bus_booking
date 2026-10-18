import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/core/utils/contact_launcher.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/features/customer/screens/booking_detail_screen.dart';

class FakeOpener implements UrlOpener {
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<FakeOpener> pump(
    WidgetTester tester, MockBackend b, Booking booking) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  b.user.value = const AppUser(
      id: 'cust_919820011223',
      role: UserRole.customer,
      name: 'Rohan',
      phone: '98200 11223',
      onboarded: true);
  b.bookings.upsert((e) => e.id == booking.id, booking);
  final opener = FakeOpener();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      mockBackendProvider.overrideWithValue(b),
      urlOpenerProvider.overrideWithValue(opener)
    ],
    child: MaterialApp(
        theme: AppTheme.light, home: BookingDetailScreen(booking: booking)),
  ));
  await settle(tester);
  return opener;
}

void main() {
  final b0 = MockBackend();
  final base = b0.bookings.items.firstWhere((e) => e.id == 'bk-0472');

  testWidgets(
      'a confirmed booking shows the driver number and a tracking button that opens the link',
      (tester) async {
    final opener = await pump(
      tester,
      MockBackend(),
      base.copyWith(
          stage: BookingStage.confirmed,
          driverPhone: '+91 90000 11122',
          gpsLink: 'https://track.example.com/bus/7'),
    );
    await tester.scrollUntilVisible(find.text('Track the bus'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('+91 90000 11122'), findsOneWidget);
    await tester.tap(find.text('Track the bus'));
    await settle(tester);
    expect(opener.opened.single.toString(), 'https://track.example.com/bus/7');
  });

  testWidgets('with no tracking link there is no tracking button',
      (tester) async {
    await pump(
        tester,
        MockBackend(),
        base.copyWith(
            stage: BookingStage.confirmed, driverPhone: '+91 90000 11122'));
    await tester.scrollUntilVisible(find.textContaining('+91 90000 11122'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Track the bus'), findsNothing);
  });

  testWidgets('a link that is not https is never offered', (tester) async {
    await pump(
        tester,
        MockBackend(),
        base.copyWith(
            stage: BookingStage.confirmed, gpsLink: 'javascript:alert(1)'));
    expect(find.text('Track the bus'), findsNothing);
  });

  testWidgets(
      'before confirmation the driver and link are not shown even if present',
      (tester) async {
    await pump(
        tester,
        MockBackend(),
        base.copyWith(
            stage: BookingStage.costConfirmed,
            driverPhone: '+91 90000 11122',
            gpsLink: 'https://track.example.com/bus/7'));
    expect(find.text('Track the bus'), findsNothing);
    expect(find.textContaining('+91 90000 11122'), findsNothing);
  });

  test(
      'confirming a booking in the demo copies the driver number and link onto it',
      () async {
    final b = MockBackend();
    final repo = MockBookingRepository(b);
    final hold =
        b.bookings.items.firstWhere((e) => e.stage == BookingStage.requested);
    final bus = b.buses.items.firstWhere((x) => x.id == hold.busId);
    await repo.confirmCost(hold.id, 10000);
    await repo.recordAdvance(hold.id, amount: 2500);
    final done = b.bookings.items.firstWhere((e) => e.id == hold.id);
    expect(done.driverPhone,
        b.drivers.items.firstWhere((d) => d.id == bus.driverId).phone);
  });
}
