import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/data/mock_data.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/repositories/firestore/firestore_repositories.dart';
import 'package:charter_booking_ui/data/repositories/repositories.dart';

/// Stands in for the server: records every call and can be told to refuse.
class FakeServer {
  final List<(String, Map<String, dynamic>)> calls = [];
  FirebaseFunctionsException? refuse;
  Map<String, dynamic> response = {};

  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) async {
    calls.add((name, data));
    final error = refuse;
    if (error != null) throw error;
    return response;
  }
}

Map<String, dynamic> bookingDoc({String customerId = 'cust_1', String stage = 'requested'}) => {
      'reference': 'CB-20261010-0001',
      'customerId': customerId,
      'customerName': 'Rohan',
      'customerPhone': '+91 98200 11223',
      'route': 'Thane → Lonavala',
      'capacity': 20,
      'busId': 'bus-7781',
      'busReg': 'MH-04-BT-7781',
      'start': Timestamp.fromDate(DateTime(2026, 10, 10, 10)),
      'end': Timestamp.fromDate(DateTime(2026, 10, 10, 16)),
      'totalFare': 0,
      'amountPaid': 0,
      'stage': stage,
      'holdExpiresAt': Timestamp.fromDate(DateTime(2026, 10, 10, 9, 30)),
      'pickupLandmark': 'Near the station',
    };

SearchCriteria criteria() => SearchCriteria(
      pickup: const LocationEntry(id: 'l1', city: 'Thane', area: 'Thane West'),
      drop: const LocationEntry(id: 'l2', city: 'Lonavala', area: 'Tungarli'),
      pickupDate: DateTime(2026, 10, 10),
      pickupTime: const TimeOfDay(hour: 9, minute: 5),
      dropDate: DateTime(2026, 10, 10),
      dropTime: const TimeOfDay(hour: 17, minute: 0),
      isRoundTrip: false,
      returnDate: DateTime(2026, 10, 10),
      returnTime: const TimeOfDay(hour: 17, minute: 0),
      summary: 'Thane West → Tungarli',
      pickupLandmark: 'Near the station',
      capacity: 17,
    );

void main() {
  late FakeFirebaseFirestore db;
  late FakeServer server;
  String? uid;

  FirestoreBookingRepository repo({bool admin = false}) =>
      FirestoreBookingRepository(db, () => uid, server.call, isAdmin: admin);

  setUp(() {
    db = FakeFirebaseFirestore();
    server = FakeServer();
    uid = 'cust_1';
  });

  group('who sees which bookings', () {
    setUp(() async {
      await db.doc('bookings/a').set(bookingDoc(customerId: 'cust_1'));
      await db.doc('bookings/b').set(bookingDoc(customerId: 'cust_2'));
    });

    test('a customer sees only their own', () async {
      final mine = await repo().watchAll().first;
      expect(mine.map((b) => b.id), ['a']);
    });

    test('staff see all of them', () async {
      uid = 'staff_1';
      final all = await repo(admin: true).watchAll().first;
      expect(all.map((b) => b.id), unorderedEquals(['a', 'b']));
    });

    test('signed out sees nothing', () async {
      uid = null;
      expect(await repo().watchAll().first, isEmpty);
    });

    test('a booking reads back with its stage, dates and hold expiry', () async {
      final b = (await repo().watchAll().first).single;
      expect(b.stage, BookingStage.requested);
      expect(b.start, DateTime(2026, 10, 10, 10));
      expect(b.holdExpiresAt, DateTime(2026, 10, 10, 9, 30));
      expect(b.pickupLandmark, 'Near the station');
      expect(b.balanceDue, 0);
    });

    test('expired and cancelled stages are understood and no longer hold the bus', () async {
      await db.doc('bookings/c').set(bookingDoc(stage: 'expired'));
      await db.doc('bookings/d').set(bookingDoc(stage: 'cancelled'));
      final all = {for (final b in await repo().watchAll().first) b.id: b};
      expect(all['c']!.stage, BookingStage.expired);
      expect(all['c']!.occupiesBus, isFalse);
      expect(all['d']!.occupiesBus, isFalse);
      expect(all['a']!.occupiesBus, isTrue);
    });
  });

  group('holding a bus', () {
    test('sends the trip in India wall-clock time and returns the booking the server made', () async {
      await db.doc('bookings/new-1').set(bookingDoc());
      server.response = {'bookingId': 'new-1', 'reference': 'CB-20261010-0001'};

      final booking = await repo().createHold(
        bus: MockData.buses.first,
        criteria: criteria(),
        customer: const AppUser(id: 'cust_1', role: UserRole.customer),
      );

      final (name, data) = server.calls.single;
      expect(name, 'createHold');
      expect(data['busId'], MockData.buses.first.id);
      expect(data['startsAt'], '2026-10-10T09:05');
      expect(data['endsAt'], '2026-10-10T17:00');
      expect(data['route'], 'Thane West → Tungarli');
      expect(data['pickupLandmark'], 'Near the station');
      expect(data.containsKey('holdFor'), isFalse, reason: 'the server decides how long a hold lasts');
      expect(booking.id, 'new-1');
      expect(booking.reference, 'CB-20261010-0001');
    });

    test('a bus taken meanwhile becomes BusUnavailableException', () async {
      server.refuse = FirebaseFunctionsException(message: 'bus-unavailable', code: 'failed-precondition');
      await expectLater(
        repo().createHold(
          bus: MockData.buses.first,
          criteria: criteria(),
          customer: const AppUser(id: 'cust_1', role: UserRole.customer),
        ),
        throwsA(isA<BusUnavailableException>()),
      );
    });

    test('the hold limit and other refusals reach the customer in words', () async {
      server.refuse = FirebaseFunctionsException(message: 'You already have several buses on hold.', code: 'resource-exhausted');
      await expectLater(
        repo().createHold(
          bus: MockData.buses.first,
          criteria: criteria(),
          customer: const AppUser(id: 'cust_1', role: UserRole.customer),
        ),
        throwsA(isA<BookingException>().having((e) => e.message, 'message', contains('several buses'))),
      );
    });

    test('being offline says so', () async {
      server.refuse = FirebaseFunctionsException(message: 'x', code: 'unavailable');
      await expectLater(
        repo().createHold(
          bus: MockData.buses.first,
          criteria: criteria(),
          customer: const AppUser(id: 'cust_1', role: UserRole.customer),
        ),
        throwsA(isA<BookingException>().having((e) => e.message, 'message', contains('No internet'))),
      );
    });
  });

  group('staff actions go through the server', () {
    test('each action sends the right call', () async {
      final r = repo(admin: true);
      await r.confirmCost('bk', 18000);
      await r.recordAdvance('bk', amount: 4500, mode: 'UPI', reference: 'U1');
      await r.startTrip('bk');
      await r.completeTrip('bk');
      await r.recordBalance('bk', amount: 13500);
      await r.reallocate('bk', 'bus-2');
      await r.cancel('bk', reason: 'asked');

      expect(server.calls.every((c) => c.$1 == 'bookingAction' && c.$2['bookingId'] == 'bk'), isTrue);
      expect(server.calls.map((c) => c.$2['action']),
          ['confirmCost', 'recordAdvance', 'startTrip', 'completeTrip', 'recordBalance', 'reallocate', 'cancel']);
      expect(server.calls[0].$2['fare'], 18000);
      expect(server.calls[1].$2, containsPair('amount', 4500));
      expect(server.calls[1].$2, containsPair('reference', 'U1'));
      expect(server.calls[4].$2['mode'], 'Cash');
      expect(server.calls[5].$2['newBusId'], 'bus-2');
    });

    test("the server's refusal of an illegal step is shown as it was worded", () async {
      server.refuse = FirebaseFunctionsException(message: 'Cannot start a booking that is requested.', code: 'failed-precondition');
      await expectLater(
        repo(admin: true).startTrip('bk'),
        throwsA(isA<BookingException>().having((e) => e.message, 'message', 'Cannot start a booking that is requested.')),
      );
    });

    test('a non-staff caller is told they cannot', () async {
      server.refuse = FirebaseFunctionsException(message: 'Staff only.', code: 'permission-denied');
      await expectLater(repo().startTrip('bk'), throwsA(isA<BookingException>()));
    });

    test('reallocating into a taken bus is a BusUnavailableException', () async {
      server.refuse = FirebaseFunctionsException(message: 'bus-unavailable', code: 'failed-precondition');
      await expectLater(repo(admin: true).reallocate('bk', 'bus-2'), throwsA(isA<BusUnavailableException>()));
    });
  });

  group('search', () {
    test('the server picks the buses; they come back in its order with the full details', () async {
      final buses = FirestoreBusRepository(db, () => uid);
      for (final b in MockData.buses) {
        await buses.upsert(b);
      }
      server.response = {'busIds': [MockData.buses[2].id, MockData.buses[0].id]};

      final found = await FirestoreSearchRepository(db, () => uid, server.call, buses).availableBuses(criteria());

      expect(found.map((b) => b.id), [MockData.buses[2].id, MockData.buses[0].id]);
      final (name, data) = server.calls.single;
      expect(name, 'searchBuses');
      expect(data['startsAt'], '2026-10-10T09:05');
      expect(data['capacity'], 17);
    });

    test('a bus the server returns but the customer cannot see is dropped, not a crash', () async {
      final buses = FirestoreBusRepository(db, () => uid);
      await buses.upsert(MockData.buses.first);
      server.response = {'busIds': ['ghost', MockData.buses.first.id]};
      final found = await FirestoreSearchRepository(db, () => uid, server.call, buses).availableBuses(criteria());
      expect(found.map((b) => b.id), [MockData.buses.first.id]);
    });
  });

  group('payments, ratings, cancellations', () {
    test('payments for a booking come back oldest first', () async {
      await db.doc('payments/p2').set({'bookingId': 'bk', 'kind': 'balance', 'amount': 13500, 'mode': 'Cash', 'reference': '', 'receivedOn': Timestamp.fromDate(DateTime(2026, 10, 12)), 'recordedBy': 'Admin · Priya'});
      await db.doc('payments/p1').set({'bookingId': 'bk', 'kind': 'advance', 'amount': 4500, 'mode': 'UPI', 'reference': 'U1', 'receivedOn': Timestamp.fromDate(DateTime(2026, 10, 9)), 'recordedBy': 'Admin · Priya'});
      await db.doc('payments/other').set({'bookingId': 'other', 'kind': 'advance', 'amount': 1, 'mode': 'x', 'reference': '', 'receivedOn': Timestamp.fromDate(DateTime(2026, 10, 9)), 'recordedBy': 'x'});

      final all = await FirestorePaymentRepository(db, () => uid).watchForBooking('bk').first;
      expect(all.map((p) => '${p.kind.name}:${p.amount}'), ['advance:4500', 'balance:13500']);
      expect(all.first.reference, 'U1');
    });

    test('a rating is stamped with who gave it', () async {
      await FirestoreRatingRepository(db, () => uid).submit(
        Rating(id: 'r1', bookingId: 'bk', bus: 5, driver: 4, overall: 5, feedback: 'Great', createdAt: DateTime(2026)),
      );
      final stored = (await db.doc('ratings/r1').get()).data()!;
      expect(stored['customerId'], 'cust_1');
      expect(stored['overall'], 5);
      expect(stored['createdAt'], isNotNull);
    });

    test('a cancellation request is saved pending', () async {
      await FirestoreCancellationRepository(db, () => uid).request(
        CancellationRequest(id: 'c1', bookingId: 'bk', requestedBy: 'cust_1', createdAt: DateTime(2026), reason: 'Plans changed'),
      );
      final all = await FirestoreCancellationRepository(db, () => uid).watchAll().first;
      expect(all.single.status, CancellationStatus.pending);
      expect(all.single.reason, 'Plans changed');
    });
  });
}
