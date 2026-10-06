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

abstract class BookingRepository {
  Stream<List<Booking>> watchAll();
  Future<void> upsert(Booking booking);

  /// Holds [bus] for [criteria] on behalf of [customer]. The backend
  /// re-checks availability and creates the hold in one step, so two
  /// customers cannot hold the same bus; throws [BusUnavailableException]
  /// if it was taken in the meantime.
  Future<Booking> createHold({
    required BusRecord bus,
    required SearchCriteria criteria,
    required AppUser customer,
    required Duration holdFor,
  });
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

abstract class ReportRepository {
  Stream<List<ReportMetric>> watchMetrics();
}

abstract class ConfigRepository {
  Stream<AppConfig> watch();
  Future<void> save(AppConfig config);
}

abstract class PaymentRepository {
  Stream<List<Payment>> watchForBooking(String bookingId);
  Future<void> record(Payment payment);
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
