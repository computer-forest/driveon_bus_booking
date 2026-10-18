import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/features/auth/data/biometric_service.dart';
import 'package:charter_booking_ui/features/auth/data/secure_store.dart';
import 'package:charter_booking_ui/features/notifications/push_service.dart';
import 'package:charter_booking_ui/main.dart';

class FakeTokens implements PushTokenSource {
  final taps = StreamController<PushTap>.broadcast();
  PushTap? launch;

  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<String?> token() async => 't';
  @override
  Stream<String> get onRefresh => const Stream.empty();
  @override
  Future<void> deleteToken() async {}
  @override
  Stream<PushTap> get onTapped => taps.stream;
  @override
  Future<PushTap?> initialTap() async => launch;
}

class FakeBiometric implements BiometricService {
  FakeBiometric({List<BiometricOutcome>? outcomes}) : outcomes = outcomes ?? [];
  final List<BiometricOutcome> outcomes;
  @override
  Future<BiometricAvailability> availability() async => BiometricAvailability.available;
  @override
  Future<BiometricOutcome> authenticate({required String reason}) async =>
      outcomes.isEmpty ? BiometricOutcome.success : outcomes.removeAt(0);
}

Future<void> settle(WidgetTester tester, {int n = 6}) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<InMemorySecureStore> customerStore({bool biometric = false}) async {
  final store = InMemorySecureStore();
  await store.write(StoreKeys.sessionPhone, '9820011223');
  await store.write(StoreKeys.sessionOnboarded, 'true');
  await store.write(StoreKeys.profile('cust_919820011223'), 'Rohan Deshmukh\nr@example.com');
  await store.write(StoreKeys.biometricEnabled, biometric ? 'true' : 'false');
  return store;
}

Future<InMemorySecureStore> staffStore() async {
  final store = InMemorySecureStore();
  await store.write(StoreKeys.sessionPhone, '9820000001');
  await store.write(StoreKeys.sessionRole, 'admin');
  await store.write(StoreKeys.sessionOnboarded, 'true');
  await store.write(StoreKeys.biometricEnabled, 'false');
  return store;
}

Future<FakeTokens> launch(
  WidgetTester tester, {
  required InMemorySecureStore store,
  FakeBiometric? biometric,
  PushTap? launchTap,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final tokens = FakeTokens()..launch = launchTap;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
      biometricServiceProvider.overrideWithValue(biometric ?? FakeBiometric()),
      pushServiceProvider.overrideWith((ref) => DevicePushService(FakeFirebaseFirestore(), tokens)),
    ],
    child: const CharterBookingApp(),
  ));
  await tester.pump(const Duration(milliseconds: 1200));
  await settle(tester);
  return tokens;
}

void main() {
  group('reading the tap', () {
    test('a booking id is picked out of the push data', () {
      expect(PushTap.fromData({'bookingId': 'bk-1', 'kind': 'confirmed'}).bookingId, 'bk-1');
    });

    test('no booking, an empty one, or a strange one means no booking', () {
      expect(PushTap.fromData({'kind': 'x'}).bookingId, isNull);
      expect(PushTap.fromData({'bookingId': ''}).bookingId, isNull);
      expect(PushTap.fromData({'bookingId': 7}).bookingId, isNull);
    });
  });

  group('the service passes taps on', () {
    test('taps while the app is in the background are relayed, and the launch tap is given once', () async {
      final tokens = FakeTokens()..launch = const PushTap(bookingId: 'bk-9');
      final service = DevicePushService(FakeFirebaseFirestore(), tokens);
      final seen = <PushTap>[];
      final sub = service.taps.listen(seen.add);
      tokens.taps.add(const PushTap(bookingId: 'bk-1'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(seen, [const PushTap(bookingId: 'bk-1')]);
      expect((await service.launchTap())?.bookingId, 'bk-9');
      expect(await service.launchTap(), isNull, reason: 'the same launch must not open twice');
      await sub.cancel();
    });
  });

  group('opening the right screen', () {
    testWidgets("a customer's tap opens their booking", (tester) async {
      final tokens = await launch(tester, store: await customerStore());
      expect(find.text('Find a bus'), findsOneWidget);
      tokens.taps.add(const PushTap(bookingId: 'bk-0511'));
      await settle(tester);
      expect(find.text('Booking detail'), findsOneWidget);
      expect(find.text('BOOKING REF · CB-20261002-0511'), findsOneWidget);
    });

    testWidgets('a tap that launched the app from closed opens the booking too', (tester) async {
      await launch(tester, store: await customerStore(), launchTap: const PushTap(bookingId: 'bk-0511'));
      await settle(tester);
      expect(find.text('Booking detail'), findsOneWidget);
    });

    testWidgets('a tap about no booking opens the notifications', (tester) async {
      final tokens = await launch(tester, store: await customerStore());
      tokens.taps.add(const PushTap());
      await settle(tester);
      expect(find.text('Notifications'), findsWidgets);
      expect(find.text('Booking detail'), findsNothing);
    });

    testWidgets("a booking that cannot be found falls back to the notifications, not a blank screen", (tester) async {
      final tokens = await launch(tester, store: await customerStore());
      tokens.taps.add(const PushTap(bookingId: 'no-such-booking'));
      await settle(tester);
      expect(find.text('Booking detail'), findsNothing);
      expect(find.text('Notifications'), findsWidgets);
    });

    testWidgets("someone else's booking is not opened for a customer", (tester) async {
      final tokens = await launch(tester, store: await customerStore());
      tokens.taps.add(const PushTap(bookingId: 'bk-0474')); // belongs to Karan Mehta
      await settle(tester);
      expect(find.text('Booking detail'), findsNothing);
      expect(find.textContaining('Karan'), findsNothing);
    });

    testWidgets('a staff tap opens the staff view of the booking', (tester) async {
      final tokens = await launch(tester, store: await staffStore());
      tokens.taps.add(const PushTap(bookingId: 'bk-0474'));
      await settle(tester);
      expect(find.text('CB-20260914-0474'), findsWidgets); // the staff detail screen's title
      expect(find.text('Customer'), findsOneWidget);
    });
  });

  group('waiting for the right moment', () {
    testWidgets('while the app is locked nothing opens, and it opens once the person unlocks', (tester) async {
      final tokens = await launch(
        tester,
        store: await customerStore(biometric: true),
        biometric: FakeBiometric(outcomes: [BiometricOutcome.cancelled]),
      );
      expect(find.text('Unlock'), findsOneWidget);
      tokens.taps.add(const PushTap(bookingId: 'bk-0511'));
      await settle(tester);
      expect(find.text('Booking detail'), findsNothing);

      await tester.tap(find.text('Unlock'));
      await settle(tester);
      expect(find.text('Booking detail'), findsOneWidget);
    });

    testWidgets('signed out, a tap opens nothing and is forgotten rather than surprising the next sign-in', (tester) async {
      final tokens = await launch(tester, store: InMemorySecureStore());
      expect(find.text('Skip'), findsOneWidget);
      tokens.taps.add(const PushTap(bookingId: 'bk-0511'));
      await tester.pump(const Duration(seconds: 12)); // longer than it keeps trying
      await settle(tester);
      expect(find.text('Booking detail'), findsNothing);
      expect(find.text('Skip'), findsOneWidget);
    });
  });
}
