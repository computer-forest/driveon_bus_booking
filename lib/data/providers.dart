import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/contact_launcher.dart';
import '../features/admin/photos/photo_picker.dart';
import '../features/admin/photos/photo_processor.dart';
import '../features/auth/data/auth_config.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/biometric_service.dart';
import '../features/auth/data/msg91_otp_service.dart';
import '../features/auth/data/secure_store.dart';
import '../features/notifications/push_service.dart';
import 'mock_data.dart';
import 'reports.dart';
import 'models.dart';
import 'repositories/mock_repositories.dart';
import 'repositories/photo_repository.dart';
import 'repositories/repositories.dart';

/// The app's single seam to its backend. Today every repository is the
/// in-memory mock; with Firebase on, main.dart overrides the master-data ones
/// with the Firestore implementations (see firebase_overrides.dart) and no
/// screen changes. Bookings, payments, notifications and reports are still
/// in memory until their stages.

final mockBackendProvider = Provider<MockBackend>((ref) => MockBackend());

/// "Now" for the whole app. Pinned to the seed data's day so the prototype
/// stays coherent; becomes `DateTime.now` when real data replaces the seeds.
final clockProvider =
    Provider<DateTime Function()>((ref) => () => MockData.now);

// --- repositories --------------------------------------------------------

final busRepositoryProvider = Provider<BusRepository>(
    (ref) => MockBusRepository(ref.watch(mockBackendProvider)));
final vendorRepositoryProvider = Provider<VendorRepository>(
    (ref) => MockVendorRepository(ref.watch(mockBackendProvider)));
final driverRepositoryProvider = Provider<DriverRepository>(
    (ref) => MockDriverRepository(ref.watch(mockBackendProvider)));
final bookingRepositoryProvider = Provider<BookingRepository>(
    (ref) => MockBookingRepository(ref.watch(mockBackendProvider)));
final searchRepositoryProvider = Provider<SearchRepository>(
    (ref) => MockSearchRepository(ref.watch(mockBackendProvider)));
final staffRepositoryProvider = Provider<StaffRepository>((ref) => MockStaffRepository(ref.watch(mockBackendProvider)));
final blackoutRepositoryProvider = Provider<BlackoutRepository>(
    (ref) => MockBlackoutRepository(ref.watch(mockBackendProvider)));
final locationRepositoryProvider = Provider<LocationRepository>(
    (ref) => MockLocationRepository(ref.watch(mockBackendProvider)));
final templateRepositoryProvider = Provider<TemplateRepository>(
    (ref) => MockTemplateRepository(ref.watch(mockBackendProvider)));
final auditRepositoryProvider = Provider<AuditRepository>(
    (ref) => MockAuditRepository(ref.watch(mockBackendProvider)));
final notificationRepositoryProvider = Provider<NotificationRepository>(
    (ref) => MockNotificationRepository(ref.watch(mockBackendProvider)));
final contentRepositoryProvider =
    Provider<ContentRepository>((ref) => MockContentRepository());
final packageRepositoryProvider =
    Provider<PackageRepository>((ref) => MockPackageRepository(ref.watch(mockBackendProvider)));
final reportRepositoryProvider =
    Provider<ReportRepository>((ref) => MockReportRepository());
final configRepositoryProvider = Provider<ConfigRepository>(
    (ref) => MockConfigRepository(ref.watch(mockBackendProvider)));
final paymentRepositoryProvider = Provider<PaymentRepository>(
    (ref) => MockPaymentRepository(ref.watch(mockBackendProvider)));
final ratingRepositoryProvider = Provider<RatingRepository>(
    (ref) => MockRatingRepository(ref.watch(mockBackendProvider)));
final pushPrefsRepositoryProvider = Provider<PushPrefsRepository>(
    (ref) => MockPushPrefsRepository(ref.watch(mockBackendProvider)));
final pushPrefsProvider = StreamProvider<PushPrefs>((ref) => ref.watch(pushPrefsRepositoryProvider).watch());
final cancellationRepositoryProvider = Provider<CancellationRepository>(
    (ref) => MockCancellationRepository(ref.watch(mockBackendProvider)));

// --- bus photos ---------------------------------------------------------

/// Shrinks a picked photo before upload. Replaced with a fake in tests.
final photoProcessorProvider =
    Provider<PhotoProcessor>((ref) => const ImagePackagePhotoProcessor());

/// Opens calls and chats. Replaced with a fake in tests.
final urlOpenerProvider = Provider<UrlOpener>((ref) => const SystemUrlOpener());

/// Camera and gallery. Replaced with a fake in tests.
final photoPickerProvider =
    Provider<PhotoPicker>((ref) => ImagePickerPhotoPicker());

/// Where bus photos go. Demo mode keeps nothing; main.dart points it at
/// Cloud Storage when Firebase is on.
final photoRepositoryProvider =
    Provider<PhotoRepository>((ref) => MockPhotoRepository());

// --- sign-in -------------------------------------------------------------
// The defaults are safe stand-ins (in-memory storage, fake OTP, no
// biometrics) so tests need no setup; main.dart overrides them with the
// real services.

final authConfigProvider = Provider<AuthConfig>((ref) => const AuthConfig());
final secureStoreProvider =
    Provider<SecureStore>((ref) => InMemorySecureStore());
final otpServiceProvider = Provider<OtpService>((ref) => FakeOtpService());
final biometricServiceProvider =
    Provider<BiometricService>((ref) => const UnsupportedBiometricService());
final tokenVerifierProvider =
    Provider<TokenVerifier>((ref) => const LocalTokenVerifier());
final biometricSettingsProvider = Provider<BiometricSettings>((ref) =>
    BiometricSettings(
        ref.watch(secureStoreProvider), ref.watch(biometricServiceProvider)));

/// Registers this phone for push notifications. Off until main.dart turns it
/// on, so tests and demo mode never touch the messaging plugin.
final pushServiceProvider =
    Provider<PushService>((ref) => const NoopPushService());

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => MockAuthRepository(
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

final authNoticeProvider =
    NotifierProvider<AuthNoticeNotifier, AuthNotice?>(AuthNoticeNotifier.new);

/// Buses free for a trip, as decided by the backend. Keyed on the criteria
/// object, which the results screen holds for as long as it is open.
final searchResultsProvider =
    FutureProvider.autoDispose.family<List<BusRecord>, SearchCriteria>(
  (ref, criteria) =>
      ref.watch(searchRepositoryProvider).availableBuses(criteria),
);

// --- live reads ----------------------------------------------------------

final busesProvider = StreamProvider<List<BusRecord>>(
    (ref) => ref.watch(busRepositoryProvider).watchAll());
final vendorsProvider = StreamProvider<List<Vendor>>(
    (ref) => ref.watch(vendorRepositoryProvider).watchAll());
final driversProvider = StreamProvider<List<DriverRecord>>(
    (ref) => ref.watch(driverRepositoryProvider).watchAll());
final bookingsProvider = StreamProvider<List<Booking>>(
    (ref) => ref.watch(bookingRepositoryProvider).watchAll());
final blackoutsProvider = StreamProvider<List<BlackoutEntry>>(
    (ref) => ref.watch(blackoutRepositoryProvider).watchAll());
final locationsProvider = StreamProvider<List<LocationEntry>>(
    (ref) => ref.watch(locationRepositoryProvider).watchAll());
final recentLocationsProvider = StreamProvider<List<LocationEntry>>(
    (ref) => ref.watch(locationRepositoryProvider).watchRecent());
final templatesProvider = StreamProvider<List<MessageTemplate>>(
    (ref) => ref.watch(templateRepositoryProvider).watchAll());
final cancellationsProvider = StreamProvider<List<CancellationRequest>>(
    (ref) => ref.watch(cancellationRepositoryProvider).watchAll());
final auditLogProvider = StreamProvider<List<AuditEntry>>(
    (ref) => ref.watch(auditRepositoryProvider).watchAll());
final notificationsProvider = StreamProvider<List<AppNotification>>(
    (ref) => ref.watch(notificationRepositoryProvider).watchAll());
final allRatingsProvider = StreamProvider<List<Rating>>((ref) => ref.watch(ratingRepositoryProvider).watchAll());
final staffMembersProvider = StreamProvider<List<StaffMember>>((ref) => ref.watch(staffRepositoryProvider).watchAll());

/// The Terms or Privacy text; null until staff have written it.
final legalProvider = StreamProvider.family<LegalDocument?, LegalKind>(
  (ref, kind) => ref.watch(contentRepositoryProvider).watchLegal(kind),
);
final faqsProvider = StreamProvider<List<FaqItem>>(
    (ref) => ref.watch(contentRepositoryProvider).watchFaqs());
final packagesProvider = StreamProvider<List<PackageLocation>>(
    (ref) => ref.watch(packageRepositoryProvider).watchAll());
final allPaymentsProvider = StreamProvider<List<Payment>>(
    (ref) => ref.watch(paymentRepositoryProvider).watchAll());
final searchMissesProvider = StreamProvider<List<DateTime>>(
    (ref) => ref.watch(reportRepositoryProvider).watchSearchMisses());
final appConfigProvider = StreamProvider<AppConfig>(
    (ref) => ref.watch(configRepositoryProvider).watch());
final authStateProvider = StreamProvider<AppUser?>(
    (ref) => ref.watch(authRepositoryProvider).authState());

final paymentsForBookingProvider = StreamProvider.family<List<Payment>, String>(
  (ref, bookingId) =>
      ref.watch(paymentRepositoryProvider).watchForBooking(bookingId),
);

/// The staff reports for [period], worked out from the real records. Empty
/// figures while those are still loading.
final reportProvider =
    Provider.family<Report, ReportPeriod>((ref, period) => buildReport(
          period: period,
          now: ref.watch(clockProvider)(),
          bookings: ref.watch(bookingsProvider).items,
          payments: ref.watch(allPaymentsProvider).items,
          buses: ref.watch(busesProvider).items,
          vendors: ref.watch(vendorsProvider).items,
          searchMisses: ref.watch(searchMissesProvider).items,
        ));

/// The headline figures for today, shown on the staff dashboard.
final reportMetricsProvider = Provider<List<ReportMetric>>(
    (ref) => ref.watch(reportProvider(ReportPeriod.today)).metrics);

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
