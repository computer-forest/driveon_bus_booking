import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/firestore/firestore_repositories.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/data/repositories/repositories.dart';
import 'package:charter_booking_ui/features/admin/screens/staff_access_screen.dart';

const priya = AppUser(id: 'staff_919820000001', role: UserRole.admin, name: 'Priya', phone: '98200 00001', onboarded: true);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<MockBackend> pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final backend = MockBackend()..user.value = priya;
  await tester.pumpWidget(ProviderScope(
    overrides: [mockBackendProvider.overrideWithValue(backend)],
    child: MaterialApp(theme: AppTheme.light, home: const StaffAccessScreen()),
  ));
  await settle(tester);
  return backend;
}

void main() {
  group('demo-mode rules mirror the backend', () {
    late MockBackend b;
    late MockStaffRepository repo;

    setUp(() {
      b = MockBackend()..user.value = priya;
      repo = MockStaffRepository(b);
    });

    test('adding normalises the number and trims the name', () async {
      await repo.add(phone: '+91 98200 66003', name: '  Asha   Kulkarni ');
      final added = b.staff.items.firstWhere((m) => m.phone == '919820066003');
      expect(added.name, 'Asha Kulkarni');
      expect(added.active, isTrue);
      expect(added.displayPhone, '+91 98200 66003');
    });

    test('bad numbers and empty names are refused with a reason', () async {
      for (final bad in ['12345', '1234567890', '']) {
        await expectLater(repo.add(phone: bad, name: 'Asha'), throwsA(isA<BookingException>().having((e) => e.message, 'm', contains('valid 10-digit'))));
      }
      await expectLater(repo.add(phone: '9820066003', name: ' '), throwsA(isA<BookingException>()));
    });

    test('someone who already has access cannot be added again; a former member can', () async {
      await expectLater(repo.add(phone: '9820000001', name: 'Priya'), throwsA(isA<BookingException>().having((e) => e.message, 'm', contains('already has staff access'))));
      await repo.add(phone: '9820066007', name: 'Dev');
      await repo.setActive('9820066007', false);
      await repo.add(phone: '9820066007', name: 'Dev Again');
      expect(b.staff.items.firstWhere((m) => m.phone == '919820066007').active, isTrue);
    });

    test('you cannot switch yourself off, and the last active person cannot be switched off', () async {
      await expectLater(repo.setActive('9820000001', false), throwsA(isA<BookingException>().having((e) => e.message, 'm', contains('your own access'))));
      await repo.add(phone: '9820066008', name: 'Second');
      await repo.setActive('9820066008', false);
      b.user.value = const AppUser(id: 'staff_919820066008', role: UserRole.admin, phone: '98200 66008', onboarded: true);
      await expectLater(repo.setActive('9820000001', false), throwsA(isA<BookingException>().having((e) => e.message, 'm', contains('At least one person'))));
    });

    test('a switched-off person can no longer sign in as staff', () async {
      final auth = MockAuthRepository(b);
      await repo.add(phone: '9820066009', name: 'Temp');
      await auth.signInWithOtpToken(phone: '9820066009', accessToken: 't', staff: true);
      await auth.signOut();
      await repo.setActive('9820066009', false);
      await expectLater(auth.signInWithOtpToken(phone: '9820066009', accessToken: 't', staff: true), throwsA(isA<AuthException>()));
    });

    test('unknown numbers cannot be switched or renamed; a rename sticks', () async {
      await expectLater(repo.setActive('9820066010', false), throwsA(isA<BookingException>()));
      await expectLater(repo.rename('9820066010', 'Nobody'), throwsA(isA<BookingException>()));
      await repo.rename('9820000001', 'Priya Sharma');
      expect(b.staff.items.single.name, 'Priya Sharma');
    });
  });

  group('on Firestore', () {
    test('the list is read from the staff collection, by name, with the number as the id', () async {
      final db = FakeFirebaseFirestore();
      await db.doc('staff/919820000002').set({'name': 'zara', 'active': true});
      await db.doc('staff/919820000001').set({'name': 'Priya', 'active': true});
      await db.doc('staff/919820000003').set({'name': 'Old Hand', 'active': false});
      final list = await FirestoreStaffRepository(db, () => 'staff_1', (n, d) async => {}).watchAll().first;
      expect(list.map((m) => m.name), ['Old Hand', 'Priya', 'zara']);
      expect(list.first.active, isFalse);
      expect(list.last.phone, '919820000002');
    });

    test('changes are sent to the manageStaff function and never written directly', () async {
      final db = FakeFirebaseFirestore();
      final calls = <(String, Map<String, dynamic>)>[];
      final repo = FirestoreStaffRepository(db, () => 'staff_1', (n, d) async {
        calls.add((n, d));
        return {};
      });
      await repo.add(phone: '9820066003', name: 'Asha');
      await repo.setActive('919820066003', false);
      await repo.rename('919820066003', 'Asha K');
      expect(calls.map((c) => c.$1), ['manageStaff', 'manageStaff', 'manageStaff']);
      expect(calls[0].$2, {'action': 'add', 'phone': '9820066003', 'name': 'Asha'});
      expect(calls[1].$2, {'action': 'setActive', 'phone': '919820066003', 'active': false});
      expect(calls[2].$2['action'], 'rename');
      expect((await db.collection('staff').get()).docs, isEmpty);
    });

    test("the server's reason reaches the screen in its own words", () async {
      final repo = FirestoreStaffRepository(
        FakeFirebaseFirestore(),
        () => 'staff_1',
        (n, d) async => throw FirebaseFunctionsException(message: 'You cannot switch off your own access.', code: 'failed-precondition'),
      );
      await expectLater(repo.setActive('9820000001', false), throwsA(isA<BookingException>().having((e) => e.message, 'm', 'You cannot switch off your own access.')));
    });
  });

  group('the screen', () {
    testWidgets('lists everyone with their number, marks you, and does not let you switch yourself off', (tester) async {
      final b = await pump(tester);
      b.staff.add(const StaffMember(phone: '919820066003', name: 'Asha Kulkarni', active: true));
      await settle(tester);
      expect(find.text('Priya'), findsOneWidget);
      expect(find.text('+91 98200 00001'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Asha Kulkarni'), findsOneWidget);
      expect(find.textContaining('2 people have access'), findsOneWidget);
      expect(find.textContaining('cannot switch off your own access'), findsOneWidget);
      // Sorted by name, so Asha comes first and Priya (you) is last.
      expect(tester.widget<Switch>(find.byType(Switch).last).onChanged, isNull, reason: 'your own switch is locked');
      expect(tester.widget<Switch>(find.byType(Switch).first).onChanged, isNotNull, reason: "someone else's is not");
    });

    testWidgets('the only active person cannot be switched off, with the reason shown', (tester) async {
      await pump(tester);
      expect(find.textContaining('1 person has access'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });

    testWidgets('adding staff asks for a name and a valid number, then they appear', (tester) async {
      final b = await pump(tester);
      await tester.tap(find.text('Add staff'));
      await settle(tester);
      await tester.tap(find.text('Give staff access'));
      await settle(tester);
      expect(find.text("Enter the person's name."), findsOneWidget);
      expect(find.text('Enter your 10-digit mobile number.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Asha Kulkarni');
      await tester.enterText(find.byType(TextFormField).last, '1234567890');
      await tester.tap(find.text('Give staff access'));
      await settle(tester);
      expect(find.text('Mobile number must start with 6, 7, 8 or 9.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).last, '9820066003');
      await tester.tap(find.text('Give staff access'));
      await settle(tester);
      expect(b.staff.items.map((m) => m.name), contains('Asha Kulkarni'));
      expect(find.text('Asha Kulkarni'), findsOneWidget);
      expect(find.textContaining('can now sign in as staff'), findsOneWidget);
    });

    testWidgets('switching someone off asks first, and then they are switched off', (tester) async {
      final b = await pump(tester);
      b.staff.add(const StaffMember(phone: '919820066003', name: 'Asha Kulkarni', active: true));
      await settle(tester);

      await tester.tap(find.byType(Switch).first);
      await settle(tester);
      expect(find.textContaining('Switch off Asha Kulkarni?'), findsOneWidget);

      await tester.tap(find.text('Keep access'));
      await settle(tester);
      expect(b.staff.items.firstWhere((m) => m.name == 'Asha Kulkarni').active, isTrue);

      await tester.tap(find.byType(Switch).first);
      await settle(tester);
      await tester.tap(find.text('Switch off'));
      await settle(tester);
      expect(b.staff.items.firstWhere((m) => m.name == 'Asha Kulkarni').active, isFalse);
      expect(find.text('Switched off'), findsOneWidget);
    });

    testWidgets('someone switched off can be switched back on without asking', (tester) async {
      final b = await pump(tester);
      b.staff.add(const StaffMember(phone: '919820066003', name: 'Asha Kulkarni', active: false));
      await settle(tester);
      await tester.tap(find.byType(Switch).last);
      await settle(tester);
      expect(b.staff.items.firstWhere((m) => m.name == 'Asha Kulkarni').active, isTrue);
    });
  });
}
