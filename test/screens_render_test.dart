import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/data/mock_data.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/features/admin/screens/bus_calendar_screen.dart';
import 'package:charter_booking_ui/features/admin/screens/bus_form_screen.dart';
import 'package:charter_booking_ui/features/admin/screens/bus_list_screen.dart';
import 'package:charter_booking_ui/features/customer/screens/home_search_screen.dart';
import 'package:charter_booking_ui/features/customer/screens/package_rates_screen.dart';
import 'package:charter_booking_ui/features/customer/screens/package_seaters_screen.dart';
import 'package:charter_booking_ui/features/customer/screens/popular_packages_screen.dart';
import 'package:charter_booking_ui/features/customer/screens/results_screen.dart';

/// Renders the rebuilt screens at phone width. Overflows and layout
/// exceptions fail the test, which is what stands in for eyeballing them.
Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(child: MaterialApp(theme: AppTheme.light, home: screen)));
  await tester.pump(const Duration(milliseconds: 400));
}

SearchCriteria criteriaFor(int fromHour, int toHour) => SearchCriteria(
      pickup: const LocationEntry(city: 'Thane', area: 'Thane West'),
      drop: const LocationEntry(city: 'Pune', area: 'Hinjewadi'),
      pickupDate: DateTime(2026, 9, 14),
      pickupTime: TimeOfDay(hour: fromHour, minute: 0),
      dropDate: DateTime(2026, 9, 14),
      dropTime: TimeOfDay(hour: toHour, minute: 0),
      isRoundTrip: false,
      returnDate: DateTime(2026, 9, 14),
      returnTime: TimeOfDay(hour: toHour, minute: 0),
      summary: 'Thane West → Hinjewadi · 14 Sep 2026',
    );

void main() {
  testWidgets('calendar day view renders windows and bookings', (tester) async {
    await pumpScreen(tester, const BusCalendarScreen());

    expect(find.text('Bus calendar'), findsOneWidget);
    expect(find.text('Mon, 14 Sep'), findsOneWidget);
    // MH-04-BT-7781 is an afternoon bus on weekdays.
    expect(find.text('Available 02:00 PM – 10:00 PM'), findsOneWidget);
    expect(find.text('3 trips · 0 buses free all day'), findsOneWidget);
  });

  testWidgets("calendar's trip list shows the full booking detail", (tester) async {
    await pumpScreen(tester, const BusCalendarScreen());
    final scrollable = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(find.text("Today's trips"), 300, scrollable: scrollable);
    expect(find.text("Today's trips"), findsOneWidget);

    // Rohan's confirmed trip: stage badge, driver and balance all readable
    // without tapping anything. Scrolling to the card's last line pulls
    // the whole card (including the badge above it) into view.
    await tester.scrollUntilVisible(find.textContaining('₹13,500 due'), 300, scrollable: scrollable);
    expect(find.text('CB-20260914-0472'), findsWidgets);
    expect(find.text('Confirmed'), findsWidgets);
    expect(find.textContaining('Suresh Patil'), findsWidgets);

    // Anita's trip is in progress.
    await tester.scrollUntilVisible(find.textContaining('₹9,000 due'), 300, scrollable: scrollable);
    expect(find.text('In trip'), findsWidgets);
  });

  testWidgets('tapping a booking opens its own detail screen', (tester) async {
    await pumpScreen(tester, const BusCalendarScreen());

    await tester.tap(find.text('CB-20260914-0473').first);
    await tester.pumpAndSettle();

    expect(find.text('CB-20260914-0473'), findsOneWidget);
    expect(find.text('Anita Kulkarni'), findsOneWidget);
  });

  testWidgets('calendar steps to another day', (tester) async {
    await pumpScreen(tester, const BusCalendarScreen());

    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Tue, 15 Sep'), findsOneWidget);
  });

  testWidgets('calendar shows a closed day as unavailable', (tester) async {
    await pumpScreen(tester, const BusCalendarScreen());

    // Step forward to Saturday, when MH-04-BT-7781 is closed.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Sat, 19 Sep'), findsOneWidget);
    expect(find.text('Unavailable'), findsWidgets);
  });

  testWidgets('bus form renders every weekday availability row', (tester) async {
    await pumpScreen(tester, BusFormScreen(bus: MockData.buses.first));
    expect(find.text('Edit bus'), findsOneWidget);

    final form = find.byType(Scrollable).first;
    for (final day in ['Monday', 'Wednesday', 'Sunday']) {
      await tester.scrollUntilVisible(find.text(day), 200, scrollable: form);
      expect(find.text(day), findsOneWidget);
    }
    // The seeded bus is an afternoon charter on weekdays.
    expect(find.text('02:00 PM'), findsWidgets);
  });

  testWidgets('choosing "add new driver" reveals the inline driver fields', (tester) async {
    await pumpScreen(tester, BusFormScreen(bus: MockData.buses.first));

    await tester.scrollUntilVisible(
      find.text('Driver'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // The seeded bus already has a driver, so the dropdown shows them.
    await tester.tap(find.text('Suresh Patil · +91 90000 11122').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ Add new driver').last);
    await tester.pumpAndSettle();

    expect(find.text('Driver name'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('Driving licence (optional)'), findsOneWidget);
  });

  testWidgets('bus list filters by registration number', (tester) async {
    await pumpScreen(tester, const BusListScreen());

    expect(find.text('MH-04-CT-9902'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '7781');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('MH-04-BT-7781'), findsOneWidget);
    expect(find.text('MH-04-CT-9902'), findsNothing);
  });

  testWidgets('bus list search matches other details too', (tester) async {
    await pumpScreen(tester, const BusListScreen());

    await tester.enterText(find.byType(TextField), 'shivneri');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('MH-04-BT-7781'), findsNothing);
    expect(find.text('MH-12-AK-1120'), findsOneWidget);
  });

  testWidgets('results list only buses free for the window', (tester) async {
    // 8–10PM on Mon 14 Sep is free — the same bus is booked 3–8PM that day.
    await pumpScreen(tester, ResultsScreen(criteria: criteriaFor(20, 22)));
    expect(find.textContaining('Available 02:00 PM'), findsWidgets);
  });

  testWidgets('a bus already booked for the requested window is excluded', (tester) async {
    // MH-04-BT-7781 is booked 3–8PM Mon 14 Sep — searching exactly that
    // window must not offer it even though the day is otherwise open.
    await pumpScreen(tester, ResultsScreen(criteria: criteriaFor(15, 20)));
    expect(find.text('No bus free for this window'), findsOneWidget);
  });

  testWidgets('results show an empty state when nothing is free', (tester) async {
    await pumpScreen(tester, ResultsScreen(criteria: criteriaFor(2, 4)));

    expect(find.text('0 buses available'), findsOneWidget);
    expect(find.text('No bus free for this window'), findsOneWidget);
  });

  group('outstation popular packages', () {
    final mumbai = MockData.packageLocations.firstWhere((l) => l.city == 'Mumbai');
    final thane = MockData.packageLocations.firstWhere((l) => l.city == 'Thane');

    testWidgets('the entry card appears only once Outstation is selected', (tester) async {
      await pumpScreen(tester, const HomeSearchScreen());

      expect(find.text('Popular outstation packages'), findsNothing);

      await tester.tap(find.text('Outstation'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Popular outstation packages'), findsOneWidget);
    });

    testWidgets('location list offers the three cities and a help footer', (tester) async {
      await pumpScreen(tester, const PopularPackagesScreen());

      expect(find.text('Popular packages available from'), findsOneWidget);
      for (final city in ['Mumbai', 'Navi Mumbai', 'Thane']) {
        expect(find.text(city), findsOneWidget);
      }
      expect(find.text('Call us'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
    });

    testWidgets('seater list offers the four classes', (tester) async {
      await pumpScreen(tester, PackageSeatersScreen(location: mumbai));

      expect(find.text('Packages from Mumbai'), findsOneWidget);
      expect(find.text('17–20 seater Tempo traveller'), findsOneWidget);
      expect(find.text('22 seater Bus'), findsOneWidget);
      expect(find.text('27–30 seater Bus'), findsOneWidget);
      expect(find.text('35–40 seater Bus'), findsOneWidget);
    });

    testWidgets('Mumbai tempo traveller chart shows the quoted rates, unflagged', (tester) async {
      final tempo = mumbai.packages.first;
      await pumpScreen(tester, PackageRatesScreen(location: mumbai, package: tempo));

      expect(find.text('Trip'), findsOneWidget);
      expect(find.text('1 day'), findsOneWidget);
      expect(find.text('2 days'), findsOneWidget);
      expect(find.text('Mumbai to Karjat & return'), findsOneWidget);
      expect(find.text('₹10,500'), findsWidgets);
      expect(find.text('₹16,000'), findsOneWidget);
      // These rates are the client's own, so they carry no caveat.
      expect(find.text('Sample rates'), findsNothing);
    });

    testWidgets('a chart with placeholder rates says so', (tester) async {
      await pumpScreen(tester, PackageRatesScreen(location: thane, package: thane.packages[1]));

      expect(find.text('Sample rates'), findsOneWidget);
    });

    testWidgets('every trip in the chart is listed', (tester) async {
      final tempo = mumbai.packages.first;
      await pumpScreen(tester, PackageRatesScreen(location: mumbai, package: tempo));

      for (final trip in tempo.trips) {
        expect(find.text('Mumbai to ${trip.destination} & return'), findsOneWidget);
      }
    });
  });
}
