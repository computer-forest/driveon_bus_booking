import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/app/app_router.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/main.dart';

/// Drives the whole app from launch, through the router, as a user would.
Future<void> launch(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: CharterBookingApp()));
  await tester.pump(const Duration(milliseconds: 1200)); // splash
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await settle(tester);
}

Future<void> signInAsCustomer(WidgetTester tester) async {
  await tapText(tester, 'Skip');
  await tester.enterText(find.byType(TextField), '9820011223');
  await tapText(tester, 'Continue');
  await enterOtp(tester, '1234');
  await tester.enterText(find.byType(TextField).first, 'Rohan Deshmukh');
  await tester.pump();
  // This phone has no biometrics, so the offer is skipped after the profile.
  await tapText(tester, 'Continue'); // profile
}

Future<void> enterOtp(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code); // auto-submits
  await settle(tester);
}

/// Staff sign in with the same OTP flow; the demo staff number is on the
/// mock allow-list.
Future<void> signInAsStaff(WidgetTester tester, {String phone = '9820000001'}) async {
  await tapText(tester, 'Skip');
  await tapText(tester, 'Staff sign in');
  await tester.enterText(find.byType(TextField), phone);
  await tapText(tester, 'Continue');
  await enterOtp(tester, '1234');
}

void main() {
  group('who goes where', () {
    test('a signed-out visitor goes to welcome', () {
      expect(destinationFor(null), '/welcome');
    });

    test('a customer mid-setup stays in the welcome flow, then goes home', () {
      const midSetup = AppUser(id: 'u', role: UserRole.customer, onboarded: false);
      const done = AppUser(id: 'u', role: UserRole.customer, onboarded: true);
      expect(destinationFor(midSetup), '/welcome');
      expect(destinationFor(done), '/home');
    });

    test('staff go to the admin shell once their sign-in is finished', () {
      const midSetup = AppUser(id: 'a', role: UserRole.admin, onboarded: false);
      const admin = AppUser(id: 'a', role: UserRole.admin, onboarded: true);
      expect(destinationFor(midSetup), '/welcome');
      expect(destinationFor(admin), '/admin');
    });
  });

  testWidgets('launch shows the splash, then the welcome flow', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: CharterBookingApp()));
    await tester.pump();

    expect(find.text('Charter Booking'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1200));
    await settle(tester);

    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Hire the whole bus'), findsOneWidget);
  });

  testWidgets('a new customer signs in, sets up, and lands on search', (tester) async {
    await launch(tester);
    await signInAsCustomer(tester);

    expect(find.text('Find a bus'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('a wrong code is refused with a message and the boxes clear', (tester) async {
    await launch(tester);
    await tapText(tester, 'Skip');
    await tester.enterText(find.byType(TextField), '9820011223');
    await tapText(tester, 'Continue');
    await enterOtp(tester, '0000');

    expect(find.text('That code is incorrect. Check the SMS and try again.'), findsOneWidget);
    expect(find.text('Verify & continue'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('profile shows the name just entered and logging out returns to welcome', (tester) async {
    await launch(tester);
    await signInAsCustomer(tester);

    await tapText(tester, 'Profile');
    expect(find.text('Rohan Deshmukh'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Log out'), 200, scrollable: find.byType(Scrollable).first);
    await tapText(tester, 'Log out');

    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Find a bus'), findsNothing);
  });

  testWidgets("the demo customer sees their own bookings, filtered by tab", (tester) async {
    await launch(tester);
    await signInAsCustomer(tester);

    await tapText(tester, 'My bookings');
    expect(find.text('Thane → Mahabaleshwar'), findsOneWidget);
    expect(find.text('Mumbai → Alibaug'), findsOneWidget);
    // Someone else's booking is not shown.
    expect(find.text('Mumbai → Lonavala'), findsNothing);

    await tapText(tester, 'History');
    expect(find.text('Thane → Mahabaleshwar'), findsNothing);
    expect(find.text('No history bookings.'), findsOneWidget);
  });

  testWidgets('staff sign in by OTP lands on the admin dashboard and can sign out', (tester) async {
    await launch(tester);
    await signInAsStaff(tester);

    expect(find.textContaining('Good morning'), findsOneWidget);
    expect(find.text('Find a bus'), findsNothing);

    await tester.tap(find.byTooltip('Sign out'));
    await settle(tester);

    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('a number that is not staff is refused after a correct OTP', (tester) async {
    await launch(tester);
    await signInAsStaff(tester, phone: '9820011223');

    expect(find.text('This number is not registered for staff access.'), findsOneWidget);
    expect(find.textContaining('Good morning'), findsNothing);
    expect(find.text('Staff sign in'), findsWidgets); // back on the staff number screen
  });
}
