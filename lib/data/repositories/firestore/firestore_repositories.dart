import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

  @override
  Stream<LegalDocument?> watchLegal(LegalKind kind) => db.doc('legal/${kind.name}').snapshots().map((s) {
        final data = s.data();
        return data == null ? null : Codec.legalFromMap(Codec.decodeMap(data));
      });

  @override
  Future<void> saveLegal(LegalKind kind, List<LegalSection> sections) =>
      db.doc('legal/${kind.name}').set(stamp({'sections': Codec.legalToMap(sections)}));
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

// --- bookings (Stage 4/5) --------------------------------------------------

/// Calls a Cloud Function and returns its data. Injected so tests can stand
/// in for the server.
typedef CallFunction = Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data);

CallFunction cloudFunctionCaller([FirebaseFunctions? functions]) {
  final fns = functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');
  return (name, data) async {
    final result = await fns.httpsCallable(name).call<Object?>(data);
    final out = result.data;
    return out is Map ? Map<String, dynamic>.from(out) : <String, dynamic>{};
  };
}

String _wallClock(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}'
    'T${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Runs a callable and turns the server's refusal into something the app can
/// show. `bus-unavailable` becomes [BusUnavailableException].
Future<Map<String, dynamic>> invokeFunction(CallFunction call, String name, Map<String, dynamic> data) async {
  try {
    return await call(name, data);
  } on FirebaseFunctionsException catch (e) {
    if (e.message == 'bus-unavailable') throw const BusUnavailableException();
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        throw const BookingException('No internet connection. Check your connection and try again.');
      case 'permission-denied':
        throw const BookingException("You don't have permission to do that.");
      case 'failed-precondition':
      case 'resource-exhausted':
      case 'invalid-argument':
      case 'not-found':
        throw BookingException(e.message ?? "That didn't work. Please try again.");
      default:
        throw const BookingException("Something went wrong on our side. Please try again.");
    }
  }
}

/// A customer sees their own bookings; staff see all of them. Every change
/// goes through a Cloud Function, never a direct write.
class FirestoreBookingRepository extends FirestoreBase implements BookingRepository {
  FirestoreBookingRepository(super.db, super.currentUid, this._call, {required this.isAdmin});

  final CallFunction _call;
  final bool isAdmin;

  @override
  Stream<List<Booking>> watchAll() {
    final uid = currentUid();
    if (uid == null) return Stream.value(const []);
    final query = isAdmin
        ? db.collection('bookings')
        : db.collection('bookings').where('customerId', isEqualTo: uid);
    return list(query, Codec.bookingFromMap);
  }

  @override
  Future<Booking> createHold({
    required BusRecord bus,
    required SearchCriteria criteria,
    required AppUser customer,
  }) async {
    final result = await invokeFunction(_call, 'createHold', {
      'busId': bus.id,
      'startsAt': _wallClock(criteria.startsAt),
      'endsAt': _wallClock(criteria.endsAt),
      'route': '${criteria.pickup.area} → ${criteria.drop.area}',
      'pickupLandmark': criteria.pickupLandmark,
    });
    final snap = await db.doc('bookings/${result['bookingId']}').get();
    return Codec.bookingFromMap(snap.id, Codec.decodeMap(snap.data()!));
  }

  Future<void> _action(String bookingId, String action, [Map<String, dynamic> fields = const {}]) =>
      invokeFunction(_call, 'bookingAction', {'bookingId': bookingId, 'action': action, ...fields});

  @override
  Future<void> confirmCost(String bookingId, int fare) => _action(bookingId, 'confirmCost', {'fare': fare});

  @override
  Future<void> recordAdvance(String bookingId, {required int amount, String mode = 'UPI', String reference = ''}) =>
      _action(bookingId, 'recordAdvance', {'amount': amount, 'mode': mode, 'reference': reference});

  @override
  Future<void> startTrip(String bookingId) => _action(bookingId, 'startTrip');

  @override
  Future<void> completeTrip(String bookingId) => _action(bookingId, 'completeTrip');

  @override
  Future<void> recordBalance(String bookingId, {required int amount, String mode = 'Cash', String reference = ''}) =>
      _action(bookingId, 'recordBalance', {'amount': amount, 'mode': mode, 'reference': reference});

  @override
  Future<void> reallocate(String bookingId, String newBusId) =>
      _action(bookingId, 'reallocate', {'newBusId': newBusId});

  @override
  Future<void> cancel(
    String bookingId, {
    String reason = '',
    int refundAmount = 0,
    String mode = 'UPI',
    String reference = '',
    String? requestId,
  }) =>
      _action(bookingId, 'cancel', {
        'reason': reason,
        'refundAmount': refundAmount,
        'mode': mode,
        'reference': reference,
        if (requestId != null) 'requestId': requestId,
      });

  @override
  Future<void> declineCancellation(String bookingId, {required String requestId, String note = ''}) =>
      _action(bookingId, 'declineCancellation', {'requestId': requestId, 'note': note});
}

/// Which buses the server says are free; the bus details come from the
/// buses collection the customer can already read.
class FirestoreSearchRepository extends FirestoreBase implements SearchRepository {
  FirestoreSearchRepository(super.db, super.currentUid, this._call, this._buses);

  final CallFunction _call;
  final BusRepository _buses;

  @override
  Future<List<BusRecord>> availableBuses(SearchCriteria criteria) async {
    final result = await invokeFunction(_call, 'searchBuses', {
      'startsAt': _wallClock(criteria.startsAt),
      'endsAt': _wallClock(criteria.endsAt),
      if (criteria.capacity != null) 'capacity': criteria.capacity,
    });
    final ids = [for (final id in (result['busIds'] as List?) ?? const []) id as String];
    final all = await _buses.watchAll().first;
    return [
      for (final id in ids)
        for (final bus in all)
          if (bus.id == id) bus,
    ];
  }
}

class FirestorePaymentRepository extends FirestoreBase implements PaymentRepository {
  FirestorePaymentRepository(super.db, super.currentUid);

  @override
  Stream<List<Payment>> watchForBooking(String bookingId) =>
      list(db.collection('payments').where('bookingId', isEqualTo: bookingId), Codec.paymentFromMap)
          .map((all) => all..sort((a, b) => a.receivedOn.compareTo(b.receivedOn)));

  /// Staff only: every payment, for the reports.
  @override
  Stream<List<Payment>> watchAll() => list(db.collection('payments'), Codec.paymentFromMap);
}

class FirestoreRatingRepository extends FirestoreBase implements RatingRepository {
  FirestoreRatingRepository(super.db, super.currentUid);

  @override
  Future<void> submit(Rating rating) => db.doc('ratings/${rating.id}').set({
        ...Codec.ratingToMap(rating),
        'customerId': currentUid(),
        'createdAt': FieldValue.serverTimestamp(),
      });
}

class FirestoreCancellationRepository extends FirestoreBase implements CancellationRepository {
  FirestoreCancellationRepository(super.db, super.currentUid, {this.isAdmin = false});

  final bool isAdmin;

  /// Staff see every request; a customer sees only their own.
  @override
  Stream<List<CancellationRequest>> watchAll() {
    final uid = currentUid();
    if (uid == null) return Stream.value(const []);
    final query = isAdmin
        ? db.collection('cancellations')
        : db.collection('cancellations').where('requestedBy', isEqualTo: uid);
    return list(query, Codec.cancellationFromMap);
  }

  @override
  Future<void> request(CancellationRequest request) => db.doc('cancellations/${request.id}').set({
        ...Codec.cancellationToMap(request),
        'createdAt': FieldValue.serverTimestamp(),
      });
}

/// The customer's or staff member's inbox. The server writes every entry;
/// the app can only mark one read.
class FirestoreNotificationRepository extends FirestoreBase implements NotificationRepository {
  FirestoreNotificationRepository(super.db, super.currentUid);

  @override
  Stream<List<AppNotification>> watchAll() {
    final uid = currentUid();
    if (uid == null) return Stream.value(const []);
    return list(
      db.collection('notifications').where('userId', isEqualTo: uid).orderBy('createdAt', descending: true).limit(50),
      Codec.notificationFromMap,
    );
  }

  @override
  Future<void> markRead(String id) => db.doc('notifications/$id').update({'read': true});
}

class FirestoreReportRepository extends FirestoreBase implements ReportRepository {
  FirestoreReportRepository(super.db, super.currentUid);

  @override
  Stream<List<DateTime>> watchSearchMisses() => db.collection('searchMisses').snapshots().map((s) => [
        for (final d in s.docs)
          if (d.data()['at'] is Timestamp) (d.data()['at'] as Timestamp).toDate(),
      ]);
}

/// Reading the staff list is allowed for staff only; every change goes through
/// the manageStaff function, which enforces the rules.
class FirestoreStaffRepository extends FirestoreBase implements StaffRepository {
  FirestoreStaffRepository(super.db, super.currentUid, this._call);

  final CallFunction _call;

  @override
  Stream<List<StaffMember>> watchAll() => list(
        db.collection('staff'),
        (id, data) => StaffMember(
          phone: id,
          name: data['name'] is String ? data['name'] as String : '',
          active: data['active'] == true,
        ),
      ).map((all) => all..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));

  Future<void> _manage(Map<String, dynamic> data) => invokeFunction(_call, 'manageStaff', data);

  @override
  Future<void> add({required String phone, required String name}) => _manage({'action': 'add', 'phone': phone, 'name': name});

  @override
  Future<void> setActive(String phone, bool active) => _manage({'action': 'setActive', 'phone': phone, 'active': active});

  @override
  Future<void> rename(String phone, String name) => _manage({'action': 'rename', 'phone': phone, 'name': name});
}
