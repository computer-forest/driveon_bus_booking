import 'package:local_auth/local_auth.dart';

import 'secure_store.dart';

enum BiometricAvailability { available, notEnrolled, unsupported }

enum BiometricOutcome { success, cancelled, lockedOut, notEnrolled, unavailable }

abstract class BiometricService {
  Future<BiometricAvailability> availability();

  /// Shows the system prompt. The device PIN/pattern is accepted as a
  /// fallback when the fingerprint or face fails.
  Future<BiometricOutcome> authenticate({required String reason});
}

class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  @override
  Future<BiometricAvailability> availability() async {
    try {
      if (!await _auth.canCheckBiometrics) return BiometricAvailability.unsupported;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isEmpty ? BiometricAvailability.notEnrolled : BiometricAvailability.available;
    } on LocalAuthException {
      return BiometricAvailability.unsupported;
    }
  }

  @override
  Future<BiometricOutcome> authenticate({required String reason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricOutcome.success : BiometricOutcome.cancelled;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.temporaryLockout || LocalAuthExceptionCode.biometricLockout => BiometricOutcome.lockedOut,
        LocalAuthExceptionCode.noBiometricsEnrolled || LocalAuthExceptionCode.noCredentialsSet => BiometricOutcome.notEnrolled,
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        LocalAuthExceptionCode.deviceError =>
          BiometricOutcome.unavailable,
        // Dismissed, timed out, backgrounded, or anything transient: the
        // customer can simply try again.
        _ => BiometricOutcome.cancelled,
      };
    }
  }
}

/// For tests and for phones without biometrics.
class UnsupportedBiometricService implements BiometricService {
  const UnsupportedBiometricService();

  @override
  Future<BiometricAvailability> availability() async => BiometricAvailability.unsupported;

  @override
  Future<BiometricOutcome> authenticate({required String reason}) async => BiometricOutcome.unavailable;
}

/// The "biometric_enabled" decision, kept in secure storage.
class BiometricSettings {
  BiometricSettings(this._store, this._service);

  final SecureStore _store;
  final BiometricService _service;

  /// null until the customer has chosen Enable or Not now.
  Future<bool?> decision() async {
    final raw = await _store.read(StoreKeys.biometricEnabled);
    return raw == null ? null : raw == 'true';
  }

  Future<bool> isEnabled() async => await decision() ?? false;

  Future<BiometricAvailability> availability() => _service.availability();

  Future<BiometricOutcome> prompt(String reason) => _service.authenticate(reason: reason);

  /// Confirms with one prompt, then remembers the choice.
  Future<BiometricOutcome> enable() async {
    switch (await _service.availability()) {
      case BiometricAvailability.unsupported:
        return BiometricOutcome.unavailable;
      case BiometricAvailability.notEnrolled:
        return BiometricOutcome.notEnrolled;
      case BiometricAvailability.available:
        break;
    }
    final outcome = await _service.authenticate(reason: 'Confirm to unlock the app with your fingerprint or face');
    if (outcome == BiometricOutcome.success) await _store.write(StoreKeys.biometricEnabled, 'true');
    return outcome;
  }

  Future<void> disable() => _store.write(StoreKeys.biometricEnabled, 'false');
}
