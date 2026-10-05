import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys held in secure storage. Nothing else is stored on the device.
class StoreKeys {
  StoreKeys._();

  /// 'true' / 'false'; absent means the customer has not been asked yet.
  static const biometricEnabled = 'biometric_enabled';

  /// The last number that completed OTP verification.
  static const lastPhone = 'last_verified_phone';

  // Used only by the on-device stand-in for the server (see MockAuthRepository).
  static const sessionPhone = 'fake_session_phone';
  static const sessionOnboarded = 'fake_session_onboarded';
  static String profile(String uid) => 'fake_profile_$uid';
}

abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStore implements SecureStore {
  // macOS: the data-protection keychain needs a signing team and a keychain
  // entitlement (error -34018 without them); the classic keychain does not.
  const FlutterSecureStore(
      [this._storage = const FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: false))]);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class InMemorySecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
