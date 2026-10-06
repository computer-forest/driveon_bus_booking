import 'dart:async';

import '../../features/auth/data/auth_messages.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/phone.dart';
import '../../features/auth/data/secure_store.dart';
import '../availability.dart';
import '../ids.dart';
import '../mock_data.dart';
import '../models.dart';
import 'in_memory_store.dart';
import 'repositories.dart';

/// Every in-memory collection behind the mock repositories. One instance
/// per app run (or per test), so state never leaks between tests the way a
/// static list would.
class MockBackend {
  MockBackend()
      : buses = InMemoryStore(MockData.buses),
        vendors = InMemoryStore(MockData.vendors),
        drivers = InMemoryStore(MockData.drivers),
        bookings = InMemoryStore(MockData.bookings),
        blackouts = InMemoryStore(MockData.blackouts),
        locations = InMemoryStore(MockData.locations),
        recentLocations = InMemoryStore(
          MockData.recentLocationIds
              .map((id) => MockData.locations.firstWhere((l) => l.id == id))
              .toList(),
        ),
        templates = InMemoryStore(MockData.templates),
        audit = InMemoryStore(MockData.auditLog),
        notifications = InMemoryStore(MockData.notifications),
        payments = InMemoryStore(MockData.payments),
        ratings = InMemoryStore<Rating>(const []),
        cancellations = InMemoryStore<CancellationRequest>(const []),
        config = InMemoryValue(const AppConfig()),
        user = InMemoryValue<AppUser?>(null);

  final InMemoryStore<BusRecord> buses;
  final InMemoryStore<Vendor> vendors;
  final InMemoryStore<DriverRecord> drivers;
  final InMemoryStore<Booking> bookings;
  final InMemoryStore<BlackoutEntry> blackouts;
  final InMemoryStore<LocationEntry> locations;
  final InMemoryStore<LocationEntry> recentLocations;
  final InMemoryStore<MessageTemplate> templates;
  final InMemoryStore<AuditEntry> audit;
  final InMemoryStore<AppNotification> notifications;
  final InMemoryStore<Payment> payments;
  final InMemoryStore<Rating> ratings;
  final InMemoryStore<CancellationRequest> cancellations;
  final InMemoryValue<AppConfig> config;
  final InMemoryValue<AppUser?> user;
}

class MockBusRepository implements BusRepository {
  MockBusRepository(this._b);
  final MockBackend _b;

  @override
  Stream<List<BusRecord>> watchAll() => _b.buses.watch();

  @override
  Future<void> upsert(BusRecord bus) async => _b.buses.upsert((e) => e.id == bus.id, bus);
}

class MockVendorRepository implements VendorRepository {
  MockVendorRepository(this._b);
  final MockBackend _b;

  @override
  Stream<List<Vendor>> watchAll() => _b.vendors.watch();

  @override
  Future<void> upsert(Vendor vendor) async => _b.vendors.upsert((e) => e.id == vendor.id, vendor);
}

class MockDriverRepository implements DriverRepository {
  MockDriverRepository(this._b);
  final MockBackend _b;

  @override
  Stream<List<DriverRecord>> watchAll() => _b.drivers.watch();

  @override
  Future<void> upsert(DriverRecord driver) async => _b.drivers.upsert((e) => e.id == driver.id, driver);
}

class MockBookingRepository implements BookingRepository {
  MockBookingRepository(this._b);
  final MockBackend _b;

  @override
  Stream<List<Booking>> watchAll() => _b.bookings.watch();

  @override
  Future<Booking> createHold({
    required BusRecord bus,
    required SearchCriteria criteria,
    required AppUser customer,
  }) async {
    final free = isBusFree(
      bus,
      criteria.startsAt,
      criteria.endsAt,
      bookings: _b.bookings.items,
      blackouts: _b.blackouts.items,
    );
    if (!free) throw const BusUnavailableException();

    final now = MockData.now;
    final datePart = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final nextSequence = _b.bookings.items
            .map((e) => int.tryParse(e.reference.split('-').last) ?? 0)
            .fold<int>(0, (a, b) => a > b ? a : b) +
        1;
    final booking = Booking(
      id: newId('bk'),
      reference: 'CB-$datePart-${nextSequence.toString().padLeft(4, '0')}',
      customerId: customer.id,
      customerName: customer.name ?? 'Customer',
      customerPhone: customer.phone == null ? '' : '+91 ${customer.phone}',
      route: '${criteria.pickup.area} → ${criteria.drop.area}',
      capacity: bus.capacity,
      busId: bus.id,
      busReg: bus.regNumber,
      start: criteria.startsAt,
      end: criteria.endsAt,
      totalFare: 0,
      amountPaid: 0,
      stage: BookingStage.requested,
      holdExpiresAt: now.add(_b.config.value.holdDuration),
      pickupLandmark: criteria.pickupLandmark.isEmpty ? null : criteria.pickupLandmark,
    );
    _b.bookings.add(booking);
    return booking;
  }

  // The same stage rules the server enforces, so the demo mode behaves alike.

  static const _editable = [BookingStage.requested, BookingStage.costConfirmed, BookingStage.confirmed];

  Booking _get(String id, List<BookingStage> allowed, String what) {
    final b = _b.bookings.items.where((e) => e.id == id).firstOrNull;
    if (b == null) throw const BookingException('No such booking.');
    if (!allowed.contains(b.stage)) {
      throw BookingException('Cannot $what a booking that is ${b.stage.name}.');
    }
    return b;
  }

  void _put(Booking b) => _b.bookings.upsert((e) => e.id == b.id, b);

  void _pay(Booking b, PaymentKind kind, int amount, String mode, String reference) {
    if (amount <= 0) return;
    _b.payments.add(Payment(
      id: newId('pay'),
      bookingId: b.id,
      kind: kind,
      amount: amount,
      mode: mode,
      reference: reference,
      receivedOn: MockData.now,
      recordedBy: 'Admin · Staff',
    ));
  }

  @override
  Future<void> confirmCost(String bookingId, int fare) async {
    final b = _get(bookingId, _editable, 'set the cost of');
    _put(b.copyWith(
      totalFare: fare,
      stage: b.stage == BookingStage.requested ? BookingStage.costConfirmed : b.stage,
    ));
  }

  @override
  Future<void> recordAdvance(String bookingId, {required int amount, String mode = 'UPI', String reference = ''}) async {
    final b = _get(bookingId, [BookingStage.requested, BookingStage.costConfirmed], 'confirm');
    if (b.totalFare <= 0) throw const BookingException('Set the cost first.');
    _pay(b, PaymentKind.advance, amount, mode, reference);
    _put(b.copyWith(amountPaid: b.amountPaid + amount, stage: BookingStage.confirmed));
  }

  @override
  Future<void> startTrip(String bookingId) async =>
      _put(_get(bookingId, [BookingStage.confirmed], 'start').copyWith(stage: BookingStage.inTrip));

  @override
  Future<void> completeTrip(String bookingId) async =>
      _put(_get(bookingId, [BookingStage.inTrip], 'complete').copyWith(stage: BookingStage.completed));

  @override
  Future<void> recordBalance(String bookingId, {required int amount, String mode = 'Cash', String reference = ''}) async {
    final b = _get(bookingId, [BookingStage.completed], 'settle');
    _pay(b, PaymentKind.balance, amount, mode, reference);
    _put(b.copyWith(amountPaid: b.amountPaid + amount, stage: BookingStage.settled));
  }

  @override
  Future<void> reallocate(String bookingId, String newBusId) async {
    final b = _get(bookingId, _editable, 'move');
    final bus = _b.buses.items.where((e) => e.id == newBusId).firstOrNull;
    if (bus == null) throw const BookingException('That bus does not exist.');
    final others = _b.bookings.items.where((e) => e.id != b.id);
    if (!isBusFree(bus, b.start, b.end, bookings: others, blackouts: _b.blackouts.items)) {
      throw const BusUnavailableException();
    }
    _put(b.copyWith(busId: bus.id, busReg: bus.regNumber));
  }

  @override
  Future<void> cancel(String bookingId, {String reason = ''}) async =>
      _put(_get(bookingId, _editable, 'cancel').copyWith(stage: BookingStage.cancelled));
}

class MockSearchRepository implements SearchRepository {
  MockSearchRepository(this._b);
  final MockBackend _b;

  @override
  Future<List<BusRecord>> availableBuses(SearchCriteria criteria) async => searchBuses(
        criteria,
        buses: _b.buses.items,
        bookings: _b.bookings.items,
        blackouts: _b.blackouts.items,
      );
}

class MockBlackoutRepository implements BlackoutRepository {
  MockBlackoutRepository(this._b);
  final MockBackend _b;

  @override
  Stream<List<BlackoutEntry>> watchAll() => _b.blackouts.watch();

  @override
  Future<void> add(BlackoutEntry entry) async => _b.blackouts.add(entry);

  @override
  Future<void> remove(String id) async => _b.blackouts.removeWhere((e) => e.id == id);
}

class MockLocationRepository implements LocationRepository {
  MockLocationRepository(this._b);
  final MockBackend _b;

  @override
  Stream<List<LocationEntry>> watchAll() => _b.locations.watch();

  @override
  Stream<List<LocationEntry>> watchRecent() => _b.recentLocations.watch();

  @override
  Future<void> markRecent(LocationEntry location) async {
    // Newest first, no repeats.
    _b.recentLocations.replaceAll([
      location,
      ..._b.recentLocations.items.where((e) => e.id != location.id),
    ]);
  }

  @override
  Future<void> add(LocationEntry location) async => _b.locations.add(location);

  @override
  Future<void> remove(String id) async {
    _b.locations.removeWhere((e) => e.id == id);
    _b.recentLocations.removeWhere((e) => e.id == id);
  }
}

class MockTemplateRepository implements TemplateRepository {
  MockTemplateRepository(this._b);
  final MockBackend _b;

  @override
  Stream<List<MessageTemplate>> watchAll() => _b.templates.watch();

  @override
  Future<void> save(MessageTemplate template) async =>
      _b.templates.upsert((e) => e.id == template.id, template);
}

class MockAuditRepository implements AuditRepository {
  MockAuditRepository(this._b);
  final MockBackend _b;

  @override
  Stream<List<AuditEntry>> watchAll() => _b.audit.watch();

}

class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository(this._b);
  final MockBackend _b;

  @override
  Stream<List<AppNotification>> watchAll() => _b.notifications.watch();

  @override
  Future<void> markRead(String id) async {
    for (final n in _b.notifications.items) {
      if (n.id == id) _b.notifications.upsert((e) => e.id == id, n.copyWith(read: true));
    }
  }
}

class MockContentRepository implements ContentRepository {
  @override
  Stream<List<FaqItem>> watchFaqs() => Stream.value(MockData.faqs);
}

class MockPackageRepository implements PackageRepository {
  @override
  Stream<List<PackageLocation>> watchAll() => Stream.value(MockData.packageLocations);
}

class MockReportRepository implements ReportRepository {
  @override
  Stream<List<ReportMetric>> watchMetrics() => Stream.value(MockData.reportMetrics);
}

class MockConfigRepository implements ConfigRepository {
  MockConfigRepository(this._b);
  final MockBackend _b;

  @override
  Stream<AppConfig> watch() => _b.config.watch();

  @override
  Future<void> save(AppConfig config) async => _b.config.value = config;
}

class MockPaymentRepository implements PaymentRepository {
  MockPaymentRepository(this._b);
  final MockBackend _b;

  @override
  Stream<List<Payment>> watchForBooking(String bookingId) =>
      _b.payments.watch().map((all) => all.where((p) => p.bookingId == bookingId).toList());

}

class MockRatingRepository implements RatingRepository {
  MockRatingRepository(this._b);
  final MockBackend _b;

  @override
  Future<void> submit(Rating rating) async => _b.ratings.add(rating);
}

class MockCancellationRepository implements CancellationRepository {
  MockCancellationRepository(this._b);
  final MockBackend _b;

  @override
  Stream<List<CancellationRequest>> watchAll() => _b.cancellations.watch();

  @override
  Future<void> request(CancellationRequest request) async => _b.cancellations.add(request);
}

/// Accepts any six digits as the one-time code and any non-empty password
/// for staff, so the prototype can be clicked through. The real
/// implementations verify the code with MSG91 and the password with
/// Firebase Auth.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(
    this._b, {
    SecureStore? store,
    TokenVerifier verifier = const LocalTokenVerifier(),
  })  : _store = store ?? InMemorySecureStore(),
        _verifier = verifier;

  final MockBackend _b;
  final SecureStore _store;
  final TokenVerifier _verifier;
  Future<void>? _restored;

  /// Demo staff allow-list for the on-device stand-in; the real one is the
  /// `staff` collection in Firestore.
  static const staffPhones = {'9820000001'};

  /// Stands in for Firebase keeping the session on the device: a customer
  /// who signed in earlier is restored without another OTP.
  Future<void> _restore() => _restored ??= _doRestore();

  Future<void> _doRestore() async {
    if (_b.user.value != null) return;
    final phone = await _store.read(StoreKeys.sessionPhone);
    if (phone == null) return;
    final isStaff = await _store.read(StoreKeys.sessionRole) == 'admin';
    final uid = '${isStaff ? 'staff' : 'cust'}_91$phone';
    final profile = await _readProfile(uid);
    _b.user.value = AppUser(
      id: uid,
      role: isStaff ? UserRole.admin : UserRole.customer,
      phone: Phone.pretty(phone),
      name: isStaff ? 'Staff' : profile?.$1,
      email: profile?.$2,
      onboarded: await _store.read(StoreKeys.sessionOnboarded) == 'true',
    );
  }

  Future<(String, String)?> _readProfile(String uid) async {
    final raw = await _store.read(StoreKeys.profile(uid));
    if (raw == null) return null;
    final parts = raw.split('\n');
    return (parts.first, parts.length > 1 ? parts[1] : '');
  }

  @override
  Stream<AppUser?> authState() {
    late final StreamController<AppUser?> controller;
    StreamSubscription<AppUser?>? subscription;
    var cancelled = false;
    controller = StreamController<AppUser?>(
      onListen: () async {
        await _restore();
        if (cancelled) return;
        subscription = _b.user.watch().listen(controller.add);
      },
      // Must return void: handing back the inner cancel future stalls
      // `.first` under fake async.
      onCancel: () {
        cancelled = true;
        subscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<AppUser> signInWithOtpToken({required String phone, required String accessToken, bool staff = false}) async {
    final identity = await _verifier.verify(phone: phone, accessToken: accessToken);
    if (staff && !staffPhones.contains(identity.phone)) throw const AuthException(AuthMessages.notStaff);
    final uid = staff ? 'staff_91${identity.phone}' : identity.uid;
    final profile = staff ? null : await _readProfile(uid);
    final user = AppUser(
      id: uid,
      role: staff ? UserRole.admin : UserRole.customer,
      phone: Phone.pretty(identity.phone),
      name: staff ? 'Staff' : profile?.$1,
      email: profile?.$2,
      // Still to do on this device: confirm the profile, choose biometrics.
      onboarded: false,
      createdAt: MockData.now,
    );
    await _store.write(StoreKeys.sessionPhone, identity.phone);
    await _store.write(StoreKeys.sessionRole, staff ? 'admin' : 'customer');
    await _store.write(StoreKeys.lastPhone, identity.phone);
    await _store.write(StoreKeys.sessionOnboarded, 'false');
    _b.user.value = user;
    return user;
  }

  @override
  Future<void> updateProfile({required String name, required String email}) async {
    final current = _b.user.value;
    if (current == null) return;
    await _store.write(StoreKeys.profile(current.id), '$name\n$email');
    _b.user.value = current.copyWith(name: name, email: email);
  }

  @override
  Future<void> completeOnboarding() async {
    final current = _b.user.value;
    if (current == null) return;
    await _store.write(StoreKeys.sessionOnboarded, 'true');
    _b.user.value = current.copyWith(onboarded: true);
  }

  /// Forgets the session, the biometric choice and the stored number, so
  /// the next launch starts with OTP.
  Future<void> _forgetDevice() async {
    for (final key in [
      StoreKeys.sessionPhone,
      StoreKeys.sessionRole,
      StoreKeys.sessionOnboarded,
      StoreKeys.lastPhone,
      StoreKeys.biometricEnabled,
    ]) {
      await _store.delete(key);
    }
  }

  @override
  Future<void> signOut() async {
    await _forgetDevice();
    _b.user.value = null;
  }

  @override
  Future<void> deleteAccount() async {
    final current = _b.user.value;
    if (current != null) await _store.delete(StoreKeys.profile(current.id));
    await signOut();
  }
}
