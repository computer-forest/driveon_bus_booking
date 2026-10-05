import '../../../data/repositories/repositories.dart';

/// Who MSG91 says owns the phone number.
class VerifiedIdentity {
  const VerifiedIdentity({required this.uid, required this.phone});

  /// Server-issued account id, derived from the verified number
  /// (`cust_919876543210`).
  final String uid;

  /// Ten digits, no country code.
  final String phone;
}

/// The one place the app trusts a phone number. With Firebase this calls the
/// `verifyMsg91Token` Cloud Function (see `functions/`), which checks the
/// access token with MSG91 using the Authkey and returns a custom token for
/// `signInWithCustomToken`. Swapping it in changes nothing in any screen.
abstract class TokenVerifier {
  /// Throws [AuthException] when the token is not accepted.
  Future<VerifiedIdentity> verify({required String phone, required String accessToken});
}

/// Until Firebase is wired: accepts any non-empty token and derives the
/// uid the same way the Cloud Function does.
class LocalTokenVerifier implements TokenVerifier {
  const LocalTokenVerifier();

  @override
  Future<VerifiedIdentity> verify({required String phone, required String accessToken}) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (accessToken.isEmpty || digits.length != 10) {
      throw const AuthException("We couldn't verify your number. Please try again.");
    }
    return VerifiedIdentity(uid: 'cust_91$digits', phone: digits);
  }
}
