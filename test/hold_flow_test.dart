import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/data/mock_data.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/features/customer/screens/results_screen.dart';

/// Tue 22 Sep 2026, 8AM to noon: MH-04-CT-9902 and MH-12-AK-1120 are free.
final _tuesday = DateTime(2026, 9, 22);

SearchCriteria _criteria() => SearchCriteria(
      pickup: const LocationEntry(city: 'Thane', area: 'Thane West'),
      drop: const LocationEntry(city: 'Pune', area: 'Hinjewadi'),
      pickupDate: _tuesday,
      pickupTime: const TimeOfDay(hour: 8, minute: 0),
      dropDate: _tuesday,
      dropTime: const TimeOfDay(hour: 12, minute: 0),
      isRoundTrip: false,
      returnDate: _tuesday,
      returnTime: const TimeOfDay(hour: 12, minute: 0),
      summary: 'Thane West → Hinjewadi · 22 Sep 2026',
    );

MockBackend _signedInBackend() {
  final backend = MockBackend();
  backend.user.value = const AppUser(
    id: 'cust_919820011223',
    role: UserRole.customer,
    name: 'Rohan Deshmukh',
    phone: '98200 11223',
    onboarded: true,
  );
  return backend;
}

Future<void> _pump(WidgetTester tester, MockBackend backend) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mockBackendProvider.overrideWithValue(backend)],
      child: MaterialApp(theme: AppTheme.light, home: ResultsScreen(criteria: _criteria())),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  testWidgets('selecting a bus holds it, shows the hold, and the booking is visible', (tester) async {
    final backend = _signedInBackend();
    await _pump(tester, backend);

    expect(find.text('2 buses available'), findsOneWidget);
    final before = backend.bookings.items.length;

    await tester.tap(find.text('Select this bus').first);
    await _settle(tester);
    await tester.tap(find.text('Hold this bus'));
    await _settle(tester);

    expect(find.text('Bus held for you'), findsOneWidget);
    expect(backend.bookings.items.length, before + 1);
    final hold = backend.bookings.items.last;
    expect(hold.isHold, isTrue);
    expect(hold.customerId, 'cust_919820011223');
    expect(hold.holdExpiresAt, MockData.now.add(const Duration(minutes: 30)));
    expect(find.textContaining(RegExp(r'^(30:00|29:\d\d)$')), findsOneWidget);

    await tester.tap(find.text('View booking status'));
    await _settle(tester);

    expect(find.text('Booking detail'), findsOneWidget);
    expect(find.textContaining(hold.reference), findsOneWidget);
  });

  testWidgets('if someone else holds the bus first, the customer is told and no hold is made', (tester) async {
    final backend = _signedInBackend();
    await _pump(tester, backend);

    await tester.tap(find.text('Select this bus').first);
    await _settle(tester);

    // Another customer takes the same bus while the confirmation sheet is open.
    final heldFirst = ResultsScreen(criteria: _criteria());
    expect(heldFirst, isNotNull);
    final bus = backend.buses.items.firstWhere((b) => b.id == 'bus-9902');
    await MockBookingRepository(backend).createHold(
      bus: bus,
      criteria: _criteria(),
      customer: const AppUser(id: 'usr-other', role: UserRole.customer, name: 'Other', phone: '98200 99999'),
    );
    final before = backend.bookings.items.length;

    await tester.tap(find.text('Hold this bus'));
    await _settle(tester);

    expect(find.text('That bus is no longer available for this trip.'), findsOneWidget);
    expect(find.text('Bus held for you'), findsNothing);
    expect(backend.bookings.items.length, before);
  });

  testWidgets('a held bus drops out of search for the next customer', (tester) async {
    final backend = _signedInBackend();
    final bus = backend.buses.items.firstWhere((b) => b.id == 'bus-9902');
    await MockBookingRepository(backend).createHold(
      bus: bus,
      criteria: _criteria(),
      customer: const AppUser(id: 'usr-other', role: UserRole.customer, name: 'Other', phone: '98200 99999'),
    );

    await _pump(tester, backend);

    expect(find.text('1 bus available'), findsOneWidget);
  });
}
