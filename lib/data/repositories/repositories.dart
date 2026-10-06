import '../models.dart';

/// What the app needs from its backend. Screens depend on these interfaces
/// only; the mock implementations satisfy them in memory today and the
/// Firestore ones replace them without any screen changing.
///
/// Reads are streams so a live backend can push changes. Writes are futures
/// so a live backend can fail.

abstract class BusRepository {
  Stream<List<BusRecord>> watchAll();
  Future<void> upsert(BusRecord bus);
}

abstract class VendorRepository {
  Stream<List<Vendor>> watchAll();
  Future<void> upsert(Vendor vendor);
}

abstract class DriverRepository {
  Stream<List<DriverRecord>> watchAll();
  Future<void> upsert(DriverRecord driver);
}

/// Thrown when a bus can no longer be held because another booking, a
/// blackout or its availability window now rules it out.
class BusUnavailableException implements Exception {
  const BusUnavailableException();

  @override
  String toString() => 'That bus is no longer available for this trip.';
}

/// Any booking operation the server refused, worded for the person using
/// the app (a lapsed hold, a stage that does not allow the step, a limit).
class BookingException implements Exception {
  const BookingException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class BookingRepository {
  /// A customer's own bookings, or every booking for staff.
  Stream<List<Booking>> watchAll();

  /// Holds [bus] for [criteria] on behalf of [customer]. The backend
  /// re-checks availability and creates the hold in one step, so two
  /// customers cannot hold the same bus; throws [BusUnavailableException]
  /// if it was taken in the meantime. The hold length comes from the
  /// server's configuration, not from the app.
  Future<Booking> createHold({
    required BusRecord bus,
    required SearchCriteria criteria,
    required AppUser customer,
  });

  // Staff actions. The backend checks each step is legal from the booking's
  // current stage and throws [BookingException] when it is not.

  /// Sets the fare; a fresh request becomes "cost confirmed".
  Future<void> confirmCost(String bookingId, int fare);

  /// Records the advance received outside the app and confirms the booking.
  Future<void> recordAdvance(String bookingId, {required int amount, String mode = 'UPI', String reference = ''});
  Future<void> startTrip(String bookingId);
  Future<void> completeTrip(String bookingId);

  /// Records the balance received and settles the booking.
  Future<void> recordBalance(String bookingId, {required int amount, String mode = 'Cash', String reference = ''});

  /// Moves the booking to [newBusId], same dates, if that bus is free.
  Future<void> reallocate(String bookingId, String newBusId);

  /// Cancels and releases the bus. [refundAmount] (at most what was paid) is
  /// recorded as paid back outside the app. With [requestId] this approves
  /// that customer request.
  Future<void> cancel(
    String bookingId, {
    String reason = '',
    int refundAmount = 0,
    String mode = 'UPI',
    String reference = '',
    String? requestId,
  });

  /// Turns down a customer's cancellation request; the booking stands.
  Future<void> declineCancellation(String bookingId, {required String requestId, String note = ''});
}

/// Which buses can be chartered for a trip. With a live backend the server
/// decides, because customers cannot see each other's bookings.
abstract class SearchRepository {
  Future<List<BusRecord>> availableBuses(SearchCriteria criteria);
}

abstract class BlackoutRepository {
  Stream<List<BlackoutEntry>> watchAll();
  Future<void> add(BlackoutEntry entry);
  Future<void> remove(String id);
}

abstract class LocationRepository {
  Stream<List<LocationEntry>> watchAll();

  /// The signed-in customer's most recent searches, newest first.
  Stream<List<LocationEntry>> watchRecent();

  /// Remembers [location] as a recent search for the signed-in customer.
  Future<void> markRecent(LocationEntry location);
  Future<void> add(LocationEntry location);
  Future<void> remove(String id);
}

abstract class TemplateRepository {
  Stream<List<MessageTemplate>> watchAll();
  Future<void> save(MessageTemplate template);
}

/// Read-only for the app: the server writes an entry for every staff write.
abstract class AuditRepository {
  Stream<List<AuditEntry>> watchAll();
}

abstract class NotificationRepository {
  Stream<List<AppNotification>> watchAll();
  Future<void> markRead(String id);
}

abstract class ContentRepository {
  Stream<List<FaqItem>> watchFaqs();
}

abstract class PackageRepository {
  Stream<List<PackageLocation>> watchAll();
}

/// Raw material for reports that the app cannot work out from bookings.
abstract class ReportRepository {
  /// When a search found no bus (staff only).
  Stream<List<DateTime>> watchSearchMisses();
}

abstract class ConfigRepository {
  Stream<AppConfig> watch();
  Future<void> save(AppConfig config);
}

/// Read-only for the app: payments are recorded by the server as part of a
/// staff action (recordAdvance, recordBalance).
abstract class PaymentRepository {
  Stream<List<Payment>> watchForBooking(String bookingId);

  /// Every payment, for staff reports.
  Stream<List<Payment>> watchAll();
}

abstract class RatingRepository {
  Future<void> submit(Rating rating);
}

abstract class CancellationRepository {
  Stream<List<CancellationRequest>> watchAll();
  Future<void> request(CancellationRequest request);
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository {
  /// The signed-in user, or null when signed out.
  Stream<AppUser?> authState();

  /// Completes sign-in once MSG91 has verified the number. The access token
  /// is checked server-side before any session is created. [phone] is the
  /// ten digits typed. With [staff] the number must also be on the staff
  /// allow-list, otherwise this throws an [AuthException] even though the
  /// OTP was right; staff get the admin role, everyone else is a customer.
  Future<AppUser> signInWithOtpToken({required String phone, required String accessToken, bool staff = false});
  Future<void> updateProfile({required String name, required String email});
  Future<void> completeOnboarding();
  Future<void> signOut();

  /// Erases the customer's personal data and signs out. Financial records
  /// are retained and past bookings anonymised, server-side.
  Future<void> deleteAccount();
}
