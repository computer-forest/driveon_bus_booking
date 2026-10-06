import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../data/models.dart';
import '../../../data/repositories/repositories.dart';
import 'auth_messages.dart';
import 'phone.dart';
import 'secure_store.dart';

/// The server-side calls sign-in needs. Behind an interface so the
/// repository can be tested without a deployed backend.
abstract class BackendFunctions {
  /// Sends the MSG91 access token to `verifyMsg91Token`, which verifies it
  /// with MSG91 and returns a Firebase custom token. [phone] is only read
  /// by the local emulator; production takes the number from MSG91.
  Future<String> exchangeMsg91Token({required String accessToken, required String phone, required bool staff});

  /// Erases the signed-in customer's data and sign-in (`deleteAccount`).
  Future<void> deleteAccount();
}

class CloudBackendFunctions implements BackendFunctions {
  CloudBackendFunctions([FirebaseFunctions? functions])
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: region);

  /// Same region as the functions (`setGlobalOptions` in `functions/src`).
  static const region = 'asia-south1';
  final FirebaseFunctions _functions;

  @override
  Future<String> exchangeMsg91Token({required String accessToken, required String phone, required bool staff}) async {
    final result = await _functions.httpsCallable('verifyMsg91Token').call<Map<Object?, Object?>>({
      'accessToken': accessToken,
      'phone': phone,
      'audience': staff ? 'staff' : 'customer',
    });
    final token = result.data['customToken'];
    if (token is! String || token.isEmpty) throw const AuthException(AuthMessages.serverVerification);
    return token;
  }

  @override
  Future<void> deleteAccount() => _functions.httpsCallable('deleteAccount').call<void>();
}

/// Real sign-in: customers and staff both verify their number with MSG91
/// and exchange the token for a Firebase custom token; the server decides
/// the role (staff only if the number is on the allow-list).
///
/// What the server knows (the profile) lives in `users/{uid}`; what only
/// this phone knows (whether first-sign-in finished here) lives in secure
/// storage.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required BackendFunctions functions,
    required SecureStore store,
  })  : _auth = auth,
        _firestore = firestore,
        _functions = functions,
        _store = store;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final BackendFunctions _functions;
  final SecureStore _store;

  /// Pushed after anything that changes the user without Firebase noticing
  /// (profile edits, finishing onboarding).
  final _refreshes = StreamController<AppUser?>.broadcast();

  DocumentReference<Map<String, dynamic>> _profile(String uid) => _firestore.doc('users/$uid');

  Future<void> _refresh() async => _refreshes.add(await _toUser(_auth.currentUser));

  Future<AppUser?> _toUser(User? user) async {
    if (user == null) return null;
    final claims = (await user.getIdTokenResult()).claims;
    if (claims?['role'] == 'admin') {
      return AppUser(
        id: user.uid,
        role: UserRole.admin,
        name: user.displayName ?? 'Staff',
        email: user.email,
        phone: _phoneFromUid(user.uid),
        onboarded: await _store.read(StoreKeys.sessionOnboarded) == 'true',
      );
    }
    Map<String, dynamic>? profile;
    try {
      profile = (await _profile(user.uid).get()).data();
    } on FirebaseException {
      // Offline or rules not yet open: carry on without the profile; it is
      // re-read on the next refresh.
    }
    return AppUser(
      id: user.uid,
      role: UserRole.customer,
      name: profile?['name'] as String?,
      email: profile?['email'] as String?,
      phone: _phoneFromUid(user.uid),
      onboarded: await _store.read(StoreKeys.sessionOnboarded) == 'true',
      createdAt: (profile?['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// `cust_919820011223` / `staff_919820011223` → `98200 11223`.
  static String? _phoneFromUid(String uid) {
    final digits = uid.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? Phone.pretty(digits.substring(digits.length - 10)) : null;
  }

  @override
  Stream<AppUser?> authState() {
    late final StreamController<AppUser?> controller;
    StreamSubscription<AppUser?>? fromFirebase;
    StreamSubscription<AppUser?>? fromRefresh;
    controller = StreamController<AppUser?>(
      onListen: () {
        fromFirebase = _auth.authStateChanges().asyncMap(_toUser).listen(controller.add, onError: controller.addError);
        fromRefresh = _refreshes.stream.listen(controller.add);
      },
      onCancel: () {
        fromFirebase?.cancel();
        fromRefresh?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<AppUser> signInWithOtpToken({required String phone, required String accessToken, bool staff = false}) async {
    // The biometric offer must still be shown on this phone.
    await _store.write(StoreKeys.sessionOnboarded, 'false');
    try {
      final customToken =
          await _functions.exchangeMsg91Token(accessToken: accessToken, phone: Phone.digits(phone), staff: staff);
      await _auth.signInWithCustomToken(customToken);
    } on AuthException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      const offline = {'unavailable', 'deadline-exceeded'};
      throw AuthException(switch (e.code) {
        'permission-denied' => staff ? AuthMessages.notStaff : AuthMessages.serverVerification,
        _ when offline.contains(e.code) => AuthMessages.noInternet,
        // Our own fault (a misconfigured permission, a crash): the number is not the problem.
        'internal' || 'unknown' || 'unimplemented' || 'data-loss' => AuthMessages.serverProblem,
        _ => AuthMessages.serverVerification,
      });
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code == 'network-request-failed' ? AuthMessages.noInternet : AuthMessages.serverVerification);
    }

    final user = _auth.currentUser!;
    await _store.write(StoreKeys.lastPhone, Phone.digits(phone));
    final ref = _profile(user.uid);
    // Staff have no customer profile.
    if (!staff && !(await ref.get()).exists) {
      await ref.set({
        'name': '',
        'email': '',
        'phone': Phone.pretty(phone),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final signedIn = (await _toUser(user))!;
    _refreshes.add(signedIn);
    return signedIn;
  }

  @override
  Future<void> updateProfile({required String name, required String email}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _profile(user.uid).update({
      'name': name,
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _refresh();
  }

  @override
  Future<void> completeOnboarding() async {
    await _store.write(StoreKeys.sessionOnboarded, 'true');
    await _refresh();
  }

  Future<void> _forgetDevice() async {
    for (final key in StoreKeys.deviceKeys) {
      await _store.delete(key);
    }
  }

  @override
  Future<void> signOut() async {
    await _forgetDevice();
    await _auth.signOut();
    _refreshes.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    await _functions.deleteAccount();
    await signOut();
  }
}
