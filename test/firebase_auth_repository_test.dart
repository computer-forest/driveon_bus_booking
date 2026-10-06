import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/data/repositories/repositories.dart';
import 'package:charter_booking_ui/features/auth/data/firebase_auth_repository.dart';
import 'package:charter_booking_ui/features/auth/data/secure_store.dart';

class FakeFunctions implements BackendFunctions {
  bool reject = false;
  bool notOnStaffList = false;
  String? failWithCode;
  bool deleted = false;
  final List<String> exchanged = [];

  @override
  Future<String> exchangeMsg91Token({required String accessToken, required String phone, required bool staff}) async {
    if (reject) throw const AuthException("We couldn't verify your number. Please try again.");
    if (failWithCode != null) throw FirebaseFunctionsException(message: 'x', code: failWithCode!);
    if (staff && notOnStaffList) {
      throw FirebaseFunctionsException(message: 'denied', code: 'permission-denied');
    }
    exchanged.add('$accessToken|$phone|${staff ? 'staff' : 'customer'}');
    return 'custom-token';
  }

  @override
  Future<void> deleteAccount() async => deleted = true;
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeFunctions functions;
  late InMemorySecureStore store;

  FirebaseAuthRepository repo(MockFirebaseAuth auth) =>
      FirebaseAuthRepository(auth: auth, firestore: firestore, functions: functions, store: store);

  setUp(() {
    firestore = FakeFirebaseFirestore();
    functions = FakeFunctions();
    store = InMemorySecureStore();
  });

  group('customer sign-in', () {
    test('a verified token signs in, creates an empty profile and still needs onboarding', () async {
      final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'cust_919820011223'));
      final user = await repo(auth).signInWithOtpToken(phone: '98200 11223', accessToken: 'tok');

      expect(functions.exchanged, ['tok|9820011223|customer']);
      expect(user.id, 'cust_919820011223');
      expect(user.isAdmin, isFalse);
      expect(user.phone, '98200 11223');
      expect(user.name, '');
      expect(user.onboarded, isFalse);
      expect(await store.read(StoreKeys.lastPhone), '9820011223');

      final doc = await firestore.doc('users/cust_919820011223').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['phone'], '98200 11223');
    });

    test('a fault on our side is not blamed on the number', () async {
      functions.failWithCode = 'internal';
      final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'cust_919820011223'));
      await expectLater(
        repo(auth).signInWithOtpToken(phone: '9820011223', accessToken: 'tok'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('problem on our side'))),
      );
    });

    test('a rejected token signs nobody in', () async {
      functions.reject = true;
      final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'cust_919820011223'));
      await expectLater(
        repo(auth).signInWithOtpToken(phone: '9820011223', accessToken: 'tok'),
        throwsA(isA<AuthException>()),
      );
      expect(auth.currentUser, isNull);
    });

    test('a returning number keeps its profile but must choose biometrics again', () async {
      await firestore.doc('users/cust_919820011223').set({
        'name': 'Rohan',
        'email': 'r@example.com',
        'phone': '98200 11223',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      await store.write(StoreKeys.sessionOnboarded, 'true'); // from an earlier session
      final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'cust_919820011223'));

      final user = await repo(auth).signInWithOtpToken(phone: '9820011223', accessToken: 'tok');

      expect(user.name, 'Rohan');
      expect(user.onboarded, isFalse);
    });

    test('profile edits and finishing onboarding reach the signed-in user', () async {
      final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'cust_919820011223'));
      final repository = repo(auth);
      await repository.signInWithOtpToken(phone: '9820011223', accessToken: 'tok');

      await repository.updateProfile(name: 'Rohan', email: 'r@example.com');
      await repository.completeOnboarding();

      final doc = await firestore.doc('users/cust_919820011223').get();
      expect(doc.data()?['name'], 'Rohan');
      expect(doc.data()?['email'], 'r@example.com');
      expect(await store.read(StoreKeys.sessionOnboarded), 'true');
    });
  });

  group('session', () {
    test('a signed-in customer is restored on launch with their profile', () async {
      await firestore.doc('users/cust_919820011223').set({'name': 'Rohan', 'email': 'r@example.com'});
      await store.write(StoreKeys.sessionOnboarded, 'true');
      final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'cust_919820011223'), signedIn: true);

      final user = await repo(auth).authState().first;

      expect(user?.name, 'Rohan');
      expect(user?.onboarded, isTrue);
    });

    test('signed out means no user', () async {
      expect(await repo(MockFirebaseAuth()).authState().first, isNull);
    });

    test('logging out forgets the biometric choice and the stored number', () async {
      await store.write(StoreKeys.biometricEnabled, 'true');
      await store.write(StoreKeys.lastPhone, '9820011223');
      final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'cust_919820011223'), signedIn: true);

      await repo(auth).signOut();

      expect(auth.currentUser, isNull);
      expect(await store.read(StoreKeys.biometricEnabled), isNull);
      expect(await store.read(StoreKeys.lastPhone), isNull);
    });

    test('deleting the account calls the server function and signs out', () async {
      final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'cust_919820011223'), signedIn: true);
      await repo(auth).deleteAccount();
      expect(functions.deleted, isTrue);
      expect(auth.currentUser, isNull);
    });
  });

  group('staff sign-in', () {
    MockFirebaseAuth staffAuth() => MockFirebaseAuth(
          mockUser: MockUser(uid: 'staff_919820000001', displayName: 'Priya', customClaim: {'role': 'admin'}),
        );

    test('a number on the staff list gets the admin role, with no customer profile', () async {
      final auth = staffAuth();
      final user = await repo(auth).signInWithOtpToken(phone: '9820000001', accessToken: 'tok', staff: true);

      expect(functions.exchanged, ['tok|9820000001|staff']);
      expect(user.isAdmin, isTrue);
      expect(user.name, 'Priya');
      expect(user.phone, '98200 00001');
      expect(user.onboarded, isFalse); // still to choose biometrics on this phone
      expect((await firestore.doc('users/staff_919820000001').get()).exists, isFalse);
    });

    test('a verified number that is not on the list is refused with a clear message', () async {
      functions.notOnStaffList = true;
      final auth = staffAuth();
      await expectLater(
        repo(auth).signInWithOtpToken(phone: '9820000001', accessToken: 'tok', staff: true),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'This number is not registered for staff access.')),
      );
      expect(auth.currentUser, isNull);
    });

    test('a staff session is restored as admin once onboarding is done', () async {
      await store.write(StoreKeys.sessionOnboarded, 'true');
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'staff_919820000001', customClaim: {'role': 'admin'}),
        signedIn: true,
      );
      final user = await repo(auth).authState().first;
      expect(user?.isAdmin, isTrue);
      expect(user?.onboarded, isTrue);
    });
  });
}
