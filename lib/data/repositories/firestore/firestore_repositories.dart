import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models.dart';
import '../repositories.dart';
import 'combine.dart';
import 'firestore_codec.dart';

typedef Json = Map<String, dynamic>;

/// Shared plumbing: every staff write is stamped with who and when. The
/// rules require both, and the audit trigger on the server reads them.
class FirestoreBase {
  FirestoreBase(this.db, this.currentUid);

  final FirebaseFirestore db;
  final String? Function() currentUid;

  Json stamp(Json data) => {
        ...Codec.encode(data) as Json,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': currentUid(),
      };

  Stream<List<T>> list<T>(Query<Json> query, T Function(String id, Json data) fromDoc) =>
      query.snapshots().map((s) => [for (final d in s.docs) fromDoc(d.id, Codec.decodeMap(d.data()))]);
}

class FirestoreBusRepository extends FirestoreBase implements BusRepository {
  FirestoreBusRepository(super.db, super.currentUid);

  @override
  Stream<List<BusRecord>> watchAll() {
    final buses = db.collection('buses').snapshots();
    // Customers cannot read the staff-only GPS links; their stream just
    // carries buses without one.
    final gps = db.collection('busAdmin').snapshots().map((s) => {
          for (final d in s.docs)
            if ((d.data()['gpsLink'] as String?)?.isNotEmpty ?? false) d.id: d.data()['gpsLink'] as String,
        });
    return combineLatest2<QuerySnapshot<Json>, Map<String, String>, List<BusRecord>>(
      buses,
      gps,
      (b, links) => [
        for (final d in b.docs) Codec.busFromMap(d.id, Codec.decodeMap(d.data()), gpsLink: links[d.id]),
      ],
      fallbackB: const {},
      bMayFail: true,
    );
  }

  @override
  Future<void> upsert(BusRecord bus) async {
    final batch = db.batch();
    batch.set(db.doc('buses/${bus.id}'), stamp(Codec.busToMap(bus)));
    batch.set(db.doc('busAdmin/${bus.id}'), stamp({'gpsLink': bus.gpsLink}));
    await batch.commit();
  }
}

class FirestoreVendorRepository extends FirestoreBase implements VendorRepository {
  FirestoreVendorRepository(super.db, super.currentUid);

  @override
  Stream<List<Vendor>> watchAll() => list(db.collection('vendors'), Codec.vendorFromMap);

  @override
  Future<void> upsert(Vendor vendor) => db.doc('vendors/${vendor.id}').set(stamp(Codec.vendorToMap(vendor)));
}

class FirestoreDriverRepository extends FirestoreBase implements DriverRepository {
  FirestoreDriverRepository(super.db, super.currentUid);

  @override
  Stream<List<DriverRecord>> watchAll() => list(db.collection('drivers'), Codec.driverFromMap);

  @override
  Future<void> upsert(DriverRecord driver) => db.doc('drivers/${driver.id}').set(stamp(Codec.driverToMap(driver)));
}

class FirestoreBlackoutRepository extends FirestoreBase implements BlackoutRepository {
  FirestoreBlackoutRepository(super.db, super.currentUid);

  @override
  Stream<List<BlackoutEntry>> watchAll() => list(db.collection('blackouts'), Codec.blackoutFromMap);

  @override
  Future<void> add(BlackoutEntry entry) => db.doc('blackouts/${entry.id}').set(stamp(Codec.blackoutToMap(entry)));

  @override
  Future<void> remove(String id) => db.doc('blackouts/$id').delete();
}

class FirestoreLocationRepository extends FirestoreBase implements LocationRepository {
  FirestoreLocationRepository(super.db, super.currentUid);

  @override
  Stream<List<LocationEntry>> watchAll() => list(db.collection('locations'), Codec.locationFromMap);

  /// This customer's last searches, newest first, resolved against the
  /// location list (a removed location simply drops out).
  @override
  Stream<List<LocationEntry>> watchRecent() {
    final uid = currentUid();
    if (uid == null) return Stream.value(const []);
    final recents = db
        .collection('users/$uid/recents')
        .orderBy('at', descending: true)
        .limit(5)
        .snapshots()
        .map((s) => [for (final d in s.docs) d.id]);
    return combineLatest2<List<String>, List<LocationEntry>, List<LocationEntry>>(
      recents,
      watchAll(),
      (ids, all) => [
        for (final id in ids)
          for (final l in all)
            if (l.id == id) l,
      ],
    );
  }

  @override
  Future<void> markRecent(LocationEntry location) async {
    final uid = currentUid();
    if (uid == null || location.id.isEmpty) return;
    await db.doc('users/$uid/recents/${location.id}').set({'at': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> add(LocationEntry location) =>
      db.doc('locations/${location.id}').set(stamp(Codec.locationToMap(location)));

  @override
  Future<void> remove(String id) => db.doc('locations/$id').delete();
}

class FirestoreTemplateRepository extends FirestoreBase implements TemplateRepository {
  FirestoreTemplateRepository(super.db, super.currentUid);

  @override
  Stream<List<MessageTemplate>> watchAll() => list(db.collection('templates'), Codec.templateFromMap);

  @override
  Future<void> save(MessageTemplate template) =>
      db.doc('templates/${template.id}').set(stamp(Codec.templateToMap(template)));
}

/// Read-only: audit entries are written by the server when a staff write
/// lands (see `functions/src/audit.ts`), so they cannot be forged or skipped.
class FirestoreAuditRepository extends FirestoreBase implements AuditRepository {
  FirestoreAuditRepository(super.db, super.currentUid);

  @override
  Stream<List<AuditEntry>> watchAll() =>
      list(db.collection('auditLog').orderBy('at', descending: true).limit(200), Codec.auditFromMap);
}

class FirestoreContentRepository extends FirestoreBase implements ContentRepository {
  FirestoreContentRepository(super.db, super.currentUid);

  @override
  Stream<List<FaqItem>> watchFaqs() =>
      list(db.collection('faqs').orderBy('order'), (_, data) => Codec.faqFromMap(data));
}

class FirestorePackageRepository extends FirestoreBase implements PackageRepository {
  FirestorePackageRepository(super.db, super.currentUid);

  @override
  Stream<List<PackageLocation>> watchAll() =>
      list(db.collection('packages').orderBy('order'), (_, data) => Codec.packageFromMap(data));
}

class FirestoreConfigRepository extends FirestoreBase implements ConfigRepository {
  FirestoreConfigRepository(super.db, super.currentUid);

  /// Until staff first save one, the defaults apply.
  @override
  Stream<AppConfig> watch() => db.doc('config/app').snapshots().map((s) {
        final data = s.data();
        return data == null ? const AppConfig() : Codec.configFromMap(Codec.decodeMap(data));
      });

  @override
  Future<void> save(AppConfig config) => db.doc('config/app').set(stamp(Codec.configToMap(config)));
}
