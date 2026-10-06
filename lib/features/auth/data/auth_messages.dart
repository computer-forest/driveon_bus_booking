import 'biometric_service.dart';

/// User-facing wording for every sign-in failure.
class AuthMessages {
  AuthMessages._();

  static const noInternet = 'No internet connection. Check your connection and try again.';
  static const wrongOtp = 'That code is incorrect. Check the SMS and try again.';
  static const expiredOtp = 'This code has expired. Request a new one.';
  static const serverVerification = "We couldn't verify your number. Please try again.";
  static const sessionNotSaved = "You're verified, but we couldn't save your sign-in on this phone. Request a new code and try again.";
  static const notStaff = 'This number is not registered for staff access.';
  static const biometricNotEnrolled = 'Set up fingerprint or Face ID in your phone settings first.';
  static const biometricLocked = 'Biometrics are locked. Log in with OTP.';
  static const biometricUnavailable = 'Biometrics are no longer available on this phone. Log in with OTP.';

  /// Why a biometric attempt did not succeed, or null when it did (or was
  /// simply dismissed).
  static String? forBiometric(BiometricOutcome outcome) => switch (outcome) {
        BiometricOutcome.notEnrolled => biometricNotEnrolled,
        BiometricOutcome.lockedOut => biometricLocked,
        BiometricOutcome.unavailable => biometricUnavailable,
        BiometricOutcome.success || BiometricOutcome.cancelled => null,
      };
}
