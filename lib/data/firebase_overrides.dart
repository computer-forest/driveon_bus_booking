import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'providers.dart';
import 'repositories/firestore/firestore_repositories.dart';

/// Swaps the repositories for their Firestore versions: master data, and now
/// bookings, payments, ratings, cancellations and search. Notifications and
/// reports stay in memory until Stage 6.
List<Override> firestoreRepositoryOverrides({FirebaseFirestore? db, FirebaseAuth? auth, CallFunction? call}) {
  final firestore = db ?? FirebaseFirestore.instance;
  final firebaseAuth = auth ?? FirebaseAuth.instance;
  String? uid() => firebaseAuth.currentUser?.uid;
  final callFunction = call ?? cloudFunctionCaller();

  return [
    busRepositoryProvider.overrideWith((ref) => FirestoreBusRepository(firestore, uid)),
    vendorRepositoryProvider.overrideWith((ref) => FirestoreVendorRepository(firestore, uid)),
    driverRepositoryProvider.overrideWith((ref) => FirestoreDriverRepository(firestore, uid)),
    blackoutRepositoryProvider.overrideWith((ref) => FirestoreBlackoutRepository(firestore, uid)),
    locationRepositoryProvider.overrideWith((ref) => FirestoreLocationRepository(firestore, uid)),
    templateRepositoryProvider.overrideWith((ref) => FirestoreTemplateRepository(firestore, uid)),
    auditRepositoryProvider.overrideWith((ref) => FirestoreAuditRepository(firestore, uid)),
    contentRepositoryProvider.overrideWith((ref) => FirestoreContentRepository(firestore, uid)),
    packageRepositoryProvider.overrideWith((ref) => FirestorePackageRepository(firestore, uid)),
    configRepositoryProvider.overrideWith((ref) => FirestoreConfigRepository(firestore, uid)),
    // Rebuilt only when the signed-in person or their role changes, so the
    // booking streams are not torn down on every profile refresh.
    bookingRepositoryProvider.overrideWith((ref) {
      final isAdmin = ref.watch(authStateProvider.select((u) => u.value?.isAdmin ?? false));
      ref.watch(authStateProvider.select((u) => u.value?.id));
      return FirestoreBookingRepository(firestore, uid, callFunction, isAdmin: isAdmin);
    }),
    searchRepositoryProvider.overrideWith(
      (ref) => FirestoreSearchRepository(firestore, uid, callFunction, ref.watch(busRepositoryProvider)),
    ),
    paymentRepositoryProvider.overrideWith((ref) => FirestorePaymentRepository(firestore, uid)),
    ratingRepositoryProvider.overrideWith((ref) => FirestoreRatingRepository(firestore, uid)),
    cancellationRepositoryProvider.overrideWith((ref) {
      final isAdmin = ref.watch(authStateProvider.select((u) => u.value?.isAdmin ?? false));
      ref.watch(authStateProvider.select((u) => u.value?.id));
      return FirestoreCancellationRepository(firestore, uid, isAdmin: isAdmin);
    }),
    // The inbox follows whoever is signed in.
    notificationRepositoryProvider.overrideWith((ref) {
      ref.watch(authStateProvider.select((u) => u.value?.id));
      return FirestoreNotificationRepository(firestore, uid);
    }),
    reportRepositoryProvider.overrideWith((ref) => FirestoreReportRepository(firestore, uid)),
    // Real time, now that bookings are real.
    clockProvider.overrideWith((ref) => DateTime.now),
  ];
}
