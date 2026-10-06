import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'providers.dart';
import 'repositories/firestore/firestore_repositories.dart';

/// Swaps the master-data repositories for their Firestore versions. Bookings,
/// payments, ratings, cancellations, notifications and reports stay in
/// memory until Stages 4-6.
List<Override> firestoreRepositoryOverrides({FirebaseFirestore? db, FirebaseAuth? auth}) {
  final firestore = db ?? FirebaseFirestore.instance;
  final firebaseAuth = auth ?? FirebaseAuth.instance;
  String? uid() => firebaseAuth.currentUser?.uid;

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
  ];
}
