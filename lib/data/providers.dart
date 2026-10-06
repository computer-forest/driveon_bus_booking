import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_config.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/biometric_service.dart';
import '../features/auth/data/msg91_otp_service.dart';
import '../features/auth/data/secure_store.dart';
import 'mock_data.dart';
import 'models.dart';
import 'repositories/mock_repositories.dart';
import 'repositories/repositories.dart';

/// The app's single seam to its backend. Today every repository is the
/// in-memory mock; with Firebase on, main.dart overrides the master-data ones
/// with the Firestore implementations (see firebase_overrides.dart) and no
/// screen changes. Bookings, payments, notifications and reports are still
/// in memory until their stages.

final mockBackendProvider = Provider<MockBackend>((ref) => MockBackend());

/// "Now" for the whole app. Pinned to the seed data's day so the prototype
/// stays coherent; becomes `DateTime.now` when real data replaces the seeds.
final clockProvider = Provider<DateTime Function()>((ref) => () => MockData.now);

// --- repositories --------------------------------------------------------

final busRepositoryProvider =
    Provider<BusRepository>((ref) => MockBusRepository(ref.watch(mockBackendProvider)));
final vendorRepositoryProvider =
    Provider<VendorRepository>((ref) => MockVendorRepository(ref.watch(mockBackendProvider)));
final driverRepositoryProvider =
    Provider<DriverRepository>((ref) => MockDriverRepository(ref.watch(mockBackendProvider)));
final bookingRepositoryProvider =
    Provider<BookingRepository>((ref) => MockBookingRepository(
      ref.watch(mockBackendProvider),
      blackouts: ref.watch(blackoutRepositoryProvider),
    ));
final blackoutRepositoryProvider =
    Provider<BlackoutRepository>((ref) => MockBlackoutRepository(ref.watch(mockBackendProvider)));
final locationRepositoryProvider =
    Provider<LocationRepository>((ref) => MockLocationRepository(ref.watch(mockBackendProvider)));
final templateRepositoryProvider =
    Provider<TemplateRepository>((ref) => MockTemplateRepository(ref.watch(mockBackendProvider)));
final auditRepositoryProvider =
    Provider<AuditRepository>((ref) => MockAuditRepository(ref.watch(mockBackendProvider)));
final notificationRepositoryProvider = Provider<NotificationRepository>(
    (ref) => MockNotificationRepository(ref.watch(mockBackendProvider)));
final contentRepositoryProvider = Provider<ContentRepository>((ref) => MockContentRepository());
final packageRepositoryProvider = Provider<PackageRepository>((ref) => MockPackageRepository());
final reportRepositoryProvider = Provider<ReportRepository>((ref) => MockReportRepository());
final configRepositoryProvider =
    Provider<ConfigRepository>((ref) => MockConfigRepository(ref.watch(mockBackendProvider)));
final paymentRepositoryProvider =
    Provider<PaymentRepository>((ref) => MockPaymentRepository(ref.watch(mockBackendProvider)));
final ratingRepositoryProvider =
    Provider<RatingRepository>((ref) => MockRatingRepository(ref.watch(mockBackendProvider)));
final cancellationRepositoryProvider = Provider<CancellationRepository>(
    (ref) => MockCancellationRepository(ref.watch(mockBackendProvider)));

// --- sign-in -------------------------------------------------------------
// The defaults are safe stand-ins (in-memory storage, fake OTP, no
// biometrics) so tests need no setup; main.dart overrides them with the
// real services.

final authConfigProvider = Provider<AuthConfig>((ref) => const AuthConfig());
final secureStoreProvider = Provider<SecureStore>((ref) => InMemorySecureStore());
final otpServiceProvider = Provider<OtpService>((ref) => FakeOtpService());
final biometricServiceProvider = Provider<BiometricService>((ref) => const UnsupportedBiometricService());
final tokenVerifierProvider = Provider<TokenVerifier>((ref) => const LocalTokenVerifier());
final biometricSettingsProvider = Provider<BiometricSettings>(
    (ref) => BiometricSettings(ref.watch(secureStoreProvider), ref.watch(biometricServiceProvider)));

final authRepositoryProvider = Provider<AuthRepository>((ref) => MockAuthRepository(
      ref.watch(mockBackendProvider),
      store: ref.watch(secureStoreProvider),
      verifier: ref.watch(tokenVerifierProvider),
    ));

/// Set when a customer is sent back to OTP sign-in on purpose (biometrics
/// locked, "Use OTP instead"). The welcome flow then skips the intro and
/// the mobile screen shows [message], once.
class AuthNotice {
  const AuthNotice([this.message]);
  final String? message;
}

class AuthNoticeNotifier extends Notifier<AuthNotice?> {
  @override
  AuthNotice? build() => null;

  void show(String? message) => state = AuthNotice(message);
  void clear() => state = null;
}

final authNoticeProvider = NotifierProvider<AuthNoticeNotifier, AuthNotice?>(AuthNoticeNotifier.new);

// --- live reads ----------------------------------------------------------

final busesProvider = StreamProvider<List<BusRecord>>((ref) => ref.watch(busRepositoryProvider).watchAll());
final vendorsProvider = StreamProvider<List<Vendor>>((ref) => ref.watch(vendorRepositoryProvider).watchAll());
final driversProvider = StreamProvider<List<DriverRecord>>((ref) => ref.watch(driverRepositoryProvider).watchAll());
final bookingsProvider = StreamProvider<List<Booking>>((ref) => ref.watch(bookingRepositoryProvider).watchAll());
final blackoutsProvider =
    StreamProvider<List<BlackoutEntry>>((ref) => ref.watch(blackoutRepositoryProvider).watchAll());
final locationsProvider =
    StreamProvider<List<LocationEntry>>((ref) => ref.watch(locationRepositoryProvider).watchAll());
final recentLocationsProvider =
    StreamProvider<List<LocationEntry>>((ref) => ref.watch(locationRepositoryProvider).watchRecent());
final templatesProvider =
    StreamProvider<List<MessageTemplate>>((ref) => ref.watch(templateRepositoryProvider).watchAll());
final auditLogProvider = StreamProvider<List<AuditEntry>>((ref) => ref.watch(auditRepositoryProvider).watchAll());
final notificationsProvider =
    StreamProvider<List<AppNotification>>((ref) => ref.watch(notificationRepositoryProvider).watchAll());
final faqsProvider = StreamProvider<List<FaqItem>>((ref) => ref.watch(contentRepositoryProvider).watchFaqs());
final packagesProvider =
    StreamProvider<List<PackageLocation>>((ref) => ref.watch(packageRepositoryProvider).watchAll());
final reportMetricsProvider =
    StreamProvider<List<ReportMetric>>((ref) => ref.watch(reportRepositoryProvider).watchMetrics());
final appConfigProvider = StreamProvider<AppConfig>((ref) => ref.watch(configRepositoryProvider).watch());
final authStateProvider = StreamProvider<AppUser?>((ref) => ref.watch(authRepositoryProvider).authState());

final paymentsForBookingProvider = StreamProvider.family<List<Payment>, String>(
  (ref, bookingId) => ref.watch(paymentRepositoryProvider).watchForBooking(bookingId),
);

// --- conveniences --------------------------------------------------------

extension AsyncListItems<T> on AsyncValue<List<T>> {
  /// The loaded list, or empty while loading. Use `.when` where a loading
  /// state should be shown instead.
  List<T> get items => value ?? <T>[];
}

extension AsyncConfig on AsyncValue<AppConfig> {
  /// The loaded config, or the defaults while loading.
  AppConfig get config => value ?? const AppConfig();
}
