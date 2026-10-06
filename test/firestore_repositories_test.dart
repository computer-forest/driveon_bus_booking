import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/data/mock_data.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/repositories/firestore/firestore_codec.dart';
import 'package:charter_booking_ui/data/repositories/firestore/firestore_repositories.dart';

void main() {
  late FakeFirebaseFirestore db;
  String? uid = 'staff_919820000001';
  String? currentUid() => uid;

  setUp(() {
    db = FakeFirebaseFirestore();
    uid = 'staff_919820000001';
  });

  group('vendors and drivers', () {
    test('a vendor is stored, stamped with who saved it, and read back', () async {
      final repo = FirestoreVendorRepository(db, currentUid);
      await repo.upsert(MockData.vendors.first);

      final stored = (await db.doc('vendors/${MockData.vendors.first.id}').get()).data()!;
      expect(stored['name'], MockData.vendors.first.name);
      expect(stored['updatedBy'], 'staff_919820000001');
      expect(stored['updatedAt'], isNotNull);

      final back = await repo.watchAll().first;
      expect(back.single.name, MockData.vendors.first.name);
      expect(back.single.id, MockData.vendors.first.id);
    });

    test('saving again replaces the vendor instead of adding a second', () async {
      final repo = FirestoreVendorRepository(db, currentUid);
      final v = MockData.vendors.first;
      await repo.upsert(v);
      await repo.upsert(Vendor(id: v.id, name: 'Renamed', contactPerson: v.contactPerson, phone: v.phone, active: false));
      final all = await repo.watchAll().first;
      expect(all.length, 1);
      expect(all.single.name, 'Renamed');
      expect(all.single.active, isFalse);
    });

    test('drivers round trip', () async {
      final repo = FirestoreDriverRepository(db, currentUid);
      await repo.upsert(MockData.drivers.first);
      expect((await repo.watchAll().first).single.licenceNumber, MockData.drivers.first.licenceNumber);
    });
  });

  group('buses', () {
    test('availability windows survive, and the GPS link is kept off the customer-readable document', () async {
      final repo = FirestoreBusRepository(db, currentUid);
      final bus = BusRecord(
        id: 'bus-t',
        regNumber: 'MH-04-XX-0001',
        vendorId: 'ven-neeta',
        vendorName: 'Neeta Travels',
        capacity: 20,
        seatType: 'Pushback seats',
        ac: true,
        baseCity: 'Thane',
        driverName: 'Unassigned',
        active: true,
        gpsLink: 'https://gps.example/bus-t',
        weeklyAvailability: [
          const DayAvailability(available: true, start: TimeOfDay(hour: 6, minute: 30), end: TimeOfDay(hour: 22, minute: 15)),
          ...List.filled(6, const DayAvailability.closed()),
        ],
      );
      await repo.upsert(bus);

      final busDoc = (await db.doc('buses/bus-t').get()).data()!;
      expect(busDoc.containsKey('gpsLink'), isFalse);
      expect((await db.doc('busAdmin/bus-t').get()).data()!['gpsLink'], 'https://gps.example/bus-t');

      final back = (await repo.watchAll().first).single;
      expect(back.gpsLink, 'https://gps.example/bus-t');
      expect(back.weeklyAvailability[0].start, const TimeOfDay(hour: 6, minute: 30));
      expect(back.weeklyAvailability[0].end, const TimeOfDay(hour: 22, minute: 15));
      expect(back.weeklyAvailability[1].available, isFalse);
      expect(back.driverId, isNull);
    });

    test('a bus with no GPS link reads back without one', () async {
      final repo = FirestoreBusRepository(db, currentUid);
      await repo.upsert(MockData.buses.first);
      expect((await repo.watchAll().first).single.gpsLink, isNull);
    });
  });

  group('locations', () {
    test('add, list and remove', () async {
      final repo = FirestoreLocationRepository(db, currentUid);
      await repo.add(const LocationEntry(id: 'loc-1', city: 'Thane', area: 'Thane West'));
      await repo.add(const LocationEntry(id: 'loc-2', city: 'Pune', area: 'Hinjewadi'));
      expect((await repo.watchAll().first).map((l) => l.id), unorderedEquals(['loc-1', 'loc-2']));

      await repo.remove('loc-1');
      expect((await repo.watchAll().first).map((l) => l.id), ['loc-2']);
    });

    test('recent searches are per customer, newest first, and drop removed locations', () async {
      uid = 'cust_919820011223';
      final repo = FirestoreLocationRepository(db, currentUid);
      const a = LocationEntry(id: 'loc-a', city: 'Thane', area: 'West');
      const b = LocationEntry(id: 'loc-b', city: 'Pune', area: 'Hinjewadi');
      await db.doc('locations/loc-a').set(Codec.locationToMap(a));
      await db.doc('locations/loc-b').set(Codec.locationToMap(b));

      await repo.markRecent(a);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.markRecent(b);
      expect((await repo.watchRecent().first).map((l) => l.id), ['loc-b', 'loc-a']);

      uid = 'cust_919999999999';
      expect(await FirestoreLocationRepository(db, currentUid).watchRecent().first, isEmpty);

      uid = 'cust_919820011223';
      await db.doc('locations/loc-b').delete();
      expect((await repo.watchRecent().first).map((l) => l.id), ['loc-a']);
    });

    test('signed out there are no recent searches', () async {
      uid = null;
      expect(await FirestoreLocationRepository(db, currentUid).watchRecent().first, isEmpty);
    });
  });

  group('blackouts', () {
    test('dates are kept exactly and a blackout can be lifted', () async {
      final repo = FirestoreBlackoutRepository(db, currentUid);
      final e = MockData.blackouts.first;
      await repo.add(e);
      final back = (await repo.watchAll().first).single;
      expect(back.from, e.from);
      expect(back.to, e.to);
      expect(back.busId, e.busId);

      await repo.remove(e.id);
      expect(await repo.watchAll().first, isEmpty);
    });
  });

  group('config, templates, packages, faqs, audit', () {
    test('config falls back to the defaults until staff save one', () async {
      final repo = FirestoreConfigRepository(db, currentUid);
      expect((await repo.watch().first).holdMinutes, const AppConfig().holdMinutes);

      await repo.save(const AppConfig(holdMinutes: 20, defaultAdvancePercent: 30, supportPhone: '+91 99999 99999'));
      final saved = await repo.watch().first;
      expect(saved.holdMinutes, 20);
      expect(saved.defaultAdvancePercent, 30);
      expect(saved.supportPhone, '+91 99999 99999');
    });

    test('a template edit is saved', () async {
      final repo = FirestoreTemplateRepository(db, currentUid);
      final t = MockData.templates.first;
      await repo.save(t.copyWith(preview: 'New wording'));
      expect((await repo.watchAll().first).single.preview, 'New wording');
    });

    test('packages come back in order with their rates and sample-rate flags', () async {
      for (var i = 0; i < MockData.packageLocations.length; i++) {
        await db.doc('packages/p$i').set(Codec.packageToMap(MockData.packageLocations[i], order: i));
      }
      final all = await FirestorePackageRepository(db, currentUid).watchAll().first;
      expect(all.map((p) => p.city), MockData.packageLocations.map((p) => p.city));
      expect(all.first.packages.first.sampleRates, isFalse);
      expect(all.first.packages.first.trips.first.oneDayRate, 10500);
      expect(all.last.packages.first.sampleRates, isTrue);
    });

    test('faqs come back in order', () async {
      for (var i = 0; i < MockData.faqs.length; i++) {
        await db.doc('faqs/f$i').set(Codec.faqToMap(MockData.faqs[i], order: i));
      }
      final all = await FirestoreContentRepository(db, currentUid).watchFaqs().first;
      expect(all.map((f) => f.question), MockData.faqs.map((f) => f.question));
    });

    test('the audit log is newest first', () async {
      await db.doc('auditLog/a').set({'actor': 'A', 'action': 'Bus added', 'detail': 'x', 'at': Timestamp.fromDate(DateTime(2026, 9, 1))});
      await db.doc('auditLog/b').set({'actor': 'B', 'action': 'Bus updated', 'detail': 'y', 'at': Timestamp.fromDate(DateTime(2026, 9, 2))});
      final all = await FirestoreAuditRepository(db, currentUid).watchAll().first;
      expect(all.map((e) => e.actor), ['B', 'A']);
      expect(all.first.at, DateTime(2026, 9, 2));
    });
  });
}
