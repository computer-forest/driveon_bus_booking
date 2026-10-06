import 'package:charter_booking_ui/features/auth/data/secure_store.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/utils/date_format.dart';
import 'package:charter_booking_ui/data/mock_data.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/repositories/in_memory_store.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/data/repositories/repositories.dart';

SearchCriteria criteria(DateTime day, int fromHour, int toHour) => SearchCriteria(
      pickup: const LocationEntry(city: 'Thane', area: 'Thane West'),
      drop: const LocationEntry(city: 'Pune', area: 'Hinjewadi'),
      pickupDate: day,
      pickupTime: TimeOfDay(hour: fromHour, minute: 0),
      dropDate: day,
      dropTime: TimeOfDay(hour: toHour, minute: 0),
      isRoundTrip: false,
      returnDate: day,
      returnTime: TimeOfDay(hour: toHour, minute: 0),
      summary: 'test',
    );

const customer = AppUser(id: 'usr-1', role: UserRole.customer, name: 'Asha', phone: '98200 00001');

void main() {
  group('holds', () {
    // Tue 22 Sep 2026: MH-04-CT-9902 is open 6AM–5PM and has nothing booked.
    final tuesday = DateTime(2026, 9, 22);
    late MockBackend backend;
    late MockBookingRepository bookings;
    late BusRecord bus;

    setUp(() {
      backend = MockBackend();
      bookings = MockBookingRepository(backend);
      bus = MockData.buses.firstWhere((b) => b.id == 'bus-9902');
    });

    test('holding a free bus creates a requested booking that expires on schedule', () async {
      final hold = await bookings.createHold(
        bus: bus,
        criteria: criteria(tuesday, 8, 12),
        customer: customer,
        holdFor: const Duration(minutes: 30),
      );

      expect(hold.stage, BookingStage.requested);
      expect(hold.isHold, isTrue);
      expect(hold.busId, bus.id);
      expect(hold.customerId, customer.id);
      expect(hold.holdExpiresAt, MockData.now.add(const Duration(minutes: 30)));
      expect(hold.holdSecondsLeft(MockData.now), 30 * 60);
      expect(backend.bookings.items.where((b) => b.id == hold.id), hasLength(1));
    });

    test('the pickup landmark the customer typed is kept on the hold', () async {
      final withLandmark = SearchCriteria(
        pickup: const LocationEntry(city: 'Thane', area: 'Thane West'),
        drop: const LocationEntry(city: 'Pune', area: 'Hinjewadi'),
        pickupDate: tuesday,
        pickupTime: const TimeOfDay(hour: 8, minute: 0),
        dropDate: tuesday,
        dropTime: const TimeOfDay(hour: 12, minute: 0),
        isRoundTrip: false,
        returnDate: tuesday,
        returnTime: const TimeOfDay(hour: 12, minute: 0),
        summary: 'test',
        pickupLandmark: 'near Viviana Mall',
      );
      final hold = await bookings.createHold(
        bus: bus,
        criteria: withLandmark,
        customer: customer,
        holdFor: const Duration(minutes: 30),
      );
      expect(hold.pickupLandmark, 'near Viviana Mall');

      final plain = await bookings.createHold(
        bus: MockData.buses.firstWhere((b) => b.id == 'bus-1120'),
        criteria: criteria(tuesday, 8, 12),
        customer: customer,
        holdFor: const Duration(minutes: 30),
      );
      expect(plain.pickupLandmark, isNull);
    });

    test('references are unique and continue the sequence', () async {
      final first = await bookings.createHold(
        bus: bus,
        criteria: criteria(tuesday, 8, 10),
        customer: customer,
        holdFor: const Duration(minutes: 30),
      );
      final second = await bookings.createHold(
        bus: bus,
        criteria: criteria(tuesday, 11, 13),
        customer: customer,
        holdFor: const Duration(minutes: 30),
      );
      expect(first.reference, isNot(second.reference));
      expect(first.reference, matches(RegExp(r'^CB-20260914-\d{4}$')));
    });

    test('a second customer cannot hold the same bus for an overlapping window', () async {
      await bookings.createHold(
        bus: bus,
        criteria: criteria(tuesday, 8, 12),
        customer: customer,
        holdFor: const Duration(minutes: 30),
      );

      await expectLater(
        bookings.createHold(
          bus: bus,
          criteria: criteria(tuesday, 10, 14),
          customer: const AppUser(id: 'usr-2', role: UserRole.customer, name: 'Bala', phone: '98200 00002'),
          holdFor: const Duration(minutes: 30),
        ),
        throwsA(isA<BusUnavailableException>()),
      );
      expect(backend.bookings.items.where((b) => b.start == DateTime(2026, 9, 22, 8)), hasLength(1));
    });

    test('simultaneous attempts on the same bus produce exactly one hold', () async {
      final attempts = await Future.wait(
        List.generate(
          5,
          (i) => bookings
              .createHold(
                bus: bus,
                criteria: criteria(tuesday, 8, 12),
                customer: AppUser(id: 'usr-$i', role: UserRole.customer, phone: '9820000000$i'),
                holdFor: const Duration(minutes: 30),
              )
              .then<Object>((b) => b, onError: (Object e) => e),
        ),
      );

      expect(attempts.whereType<Booking>(), hasLength(1));
      expect(attempts.whereType<BusUnavailableException>(), hasLength(4));
    });

    test('a bus outside its charter window cannot be held', () async {
      await expectLater(
        bookings.createHold(
          bus: bus,
          criteria: criteria(tuesday, 5, 8), // opens at 6AM
          customer: customer,
          holdFor: const Duration(minutes: 30),
        ),
        throwsA(isA<BusUnavailableException>()),
      );
    });

    test('a blacked-out bus cannot be held', () async {
      final bt = MockData.buses.firstWhere((b) => b.id == 'bus-7781');
      await expectLater(
        bookings.createHold(
          bus: bt,
          criteria: criteria(DateTime(2026, 9, 21), 15, 20),
          customer: customer,
          holdFor: const Duration(minutes: 30),
        ),
        throwsA(isA<BusUnavailableException>()),
      );
    });
  });

  group('stores', () {
    test('a new listener gets the current contents, then later changes', () async {
      final store = InMemoryStore<int>([1, 2]);
      final seen = <List<int>>[];
      final sub = store.watch().listen(seen.add);

      await Future<void>.delayed(Duration.zero);
      store.add(3);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [
        [1, 2],
        [1, 2, 3],
      ]);
      await sub.cancel();
    });

    test('upsert replaces a match and appends otherwise', () {
      final store = InMemoryStore<String>(['a1', 'b1']);
      store.upsert((e) => e.startsWith('a'), 'a2');
      store.upsert((e) => e.startsWith('c'), 'c1');
      expect(store.items, ['a2', 'b1', 'c1']);
    });

    test('backends do not share state', () async {
      final one = MockBackend();
      final two = MockBackend();
      await MockVendorRepository(one).upsert(MockData.vendors.first);
      await MockBlackoutRepository(one).remove('blk-1');
      expect(one.blackouts.items.length, MockData.blackouts.length - 1);
      expect(two.blackouts.items.length, MockData.blackouts.length);
    });
  });

  group('repositories', () {
    test('vendor edits are kept', () async {
      final backend = MockBackend();
      final repo = MockVendorRepository(backend);
      final original = MockData.vendors.first;

      await repo.upsert(Vendor(
        id: original.id,
        name: 'Neeta Tours',
        contactPerson: original.contactPerson,
        phone: original.phone,
        active: false,
      ));

      final saved = backend.vendors.items.firstWhere((v) => v.id == original.id);
      expect(saved.name, 'Neeta Tours');
      expect(saved.active, isFalse);
      expect(backend.vendors.items, hasLength(MockData.vendors.length));
    });

    test('marking a notification read changes only that one', () async {
      final backend = MockBackend();
      final repo = MockNotificationRepository(backend);

      await repo.markRead('ntf-1');

      expect(backend.notifications.items.firstWhere((n) => n.id == 'ntf-1').read, isTrue);
      expect(backend.notifications.items.firstWhere((n) => n.id == 'ntf-2').read, isFalse);
    });

    test('removing a location also drops it from recents', () async {
      final backend = MockBackend();
      final repo = MockLocationRepository(backend);

      await repo.remove('loc-thane-west');

      expect(backend.locations.items.any((l) => l.id == 'loc-thane-west'), isFalse);
      expect(backend.recentLocations.items.any((l) => l.id == 'loc-thane-west'), isFalse);
    });

    test('payments are listed per booking', () async {
      final repo = MockPaymentRepository(MockBackend());
      final payments = await repo.watchForBooking('bk-0472').first;
      expect(payments.single.amount, 4500);
    });
  });

  group('auth', () {
    test('a token the server does not accept signs nobody in', () async {
      final auth = MockAuthRepository(MockBackend());
      await expectLater(auth.signInWithOtpToken(phone: '9820011223', accessToken: ''), throwsA(isA<AuthException>()));
      expect(await auth.authState().first, isNull);
    });

    test('a customer starts un-onboarded and finishes in two steps', () async {
      final backend = MockBackend();
      final auth = MockAuthRepository(backend);

      final user = await auth.signInWithOtpToken(phone: '9820011223', accessToken: 'token');
      expect(user.isAdmin, isFalse);
      expect(user.onboarded, isFalse);
      expect(user.id, 'cust_919820011223');

      await auth.updateProfile(name: 'Rohan', email: 'r@example.com');
      await auth.completeOnboarding();

      expect(backend.user.value?.name, 'Rohan');
      expect(backend.user.value?.onboarded, isTrue);
    });

    test('staff sign in only if their verified number is on the allow-list', () async {
      final backend = MockBackend();
      final auth = MockAuthRepository(backend);
      await expectLater(
        auth.signInWithOtpToken(phone: '9820011223', accessToken: 'token', staff: true),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('not registered for staff'))),
      );
      expect(backend.user.value, isNull);

      final admin = await auth.signInWithOtpToken(phone: '9820000001', accessToken: 'token', staff: true);
      expect(admin.isAdmin, isTrue);
      expect(admin.id, 'staff_919820000001');
      expect(admin.onboarded, isFalse); // still to choose biometrics on this phone
    });

    test('a staff number signing in as a customer is only a customer', () async {
      final user = await MockAuthRepository(MockBackend())
          .signInWithOtpToken(phone: '9820000001', accessToken: 'token');
      expect(user.isAdmin, isFalse);
      expect(user.id, 'cust_919820000001');
    });

    test('a staff session is restored as staff on the next launch', () async {
      final store = InMemorySecureStore();
      final first = MockAuthRepository(MockBackend(), store: store);
      await first.signInWithOtpToken(phone: '9820000001', accessToken: 'token', staff: true);
      await first.completeOnboarding();

      final restored = await MockAuthRepository(MockBackend(), store: store).authState().first;
      expect(restored?.isAdmin, isTrue);
      expect(restored?.onboarded, isTrue);
    });

    test('signing out and deleting the account both clear the session', () async {
      final backend = MockBackend();
      final auth = MockAuthRepository(backend);
      await auth.signInWithOtpToken(phone: '9820011223', accessToken: 'token');
      await auth.signOut();
      expect(backend.user.value, isNull);

      await auth.signInWithOtpToken(phone: '9820011223', accessToken: 'token');
      await auth.deleteAccount();
      expect(backend.user.value, isNull);
    });
  });

  group('config', () {
    test('advance follows the configured percentage', () {
      expect(const AppConfig().advanceFor(18000), 4500);
      expect(const AppConfig(defaultAdvancePercent: 30).advanceFor(18000), 5400);
      expect(const AppConfig().advanceFor(0), 0);
    });

    test('saving config is visible to later readers', () async {
      final backend = MockBackend();
      final repo = MockConfigRepository(backend);
      await repo.save(const AppConfig().copyWith(holdMinutes: 20));
      expect((await repo.watch().first).holdMinutes, 20);
      expect((await repo.watch().first).holdDuration, const Duration(minutes: 20));
    });
  });

  group('relative times', () {
    final now = DateTime(2026, 9, 14, 10, 45);

    test('ago', () {
      expect(AppDateFormat.ago(now.subtract(const Duration(seconds: 20)), now), 'Just now');
      expect(AppDateFormat.ago(now.subtract(const Duration(minutes: 2)), now), '2 min ago');
      expect(AppDateFormat.ago(now.subtract(const Duration(minutes: 18)), now), '18 min ago');
      expect(AppDateFormat.ago(now.subtract(const Duration(hours: 1)), now), '1 hr ago');
      expect(AppDateFormat.ago(DateTime(2026, 9, 13, 9, 30), now), 'Yesterday');
      expect(AppDateFormat.ago(DateTime(2026, 9, 10, 9, 30), now), '10 Sep');
    });

    test('day and time', () {
      expect(AppDateFormat.dayAndTime(DateTime(2026, 9, 14, 10, 42), now), 'Today, 10:42 AM');
      expect(AppDateFormat.dayAndTime(DateTime(2026, 9, 13, 18, 2), now), 'Yesterday, 06:02 PM');
      expect(AppDateFormat.dayAndTime(DateTime(2026, 9, 12, 15, 40), now), '12 Sep, 03:40 PM');
    });
  });
}
