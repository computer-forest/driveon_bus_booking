/// Everything about sign-in that can change without editing a screen.
/// Values come from `--dart-define` so a build can match whatever the MSG91
/// widget is configured with (see README, "Sign-in configuration").
class AuthConfig {
  const AuthConfig({
    this.otpLength = 4,
    this.resendCooldown = const Duration(seconds: 30),
    this.relockAfter = const Duration(minutes: 5),
    this.voiceRetryEnabled = false,
    this.countryCode = '91',
  });

  /// Must match the OTP length set on the MSG91 widget.
  final int otpLength;

  /// Wait before "Resend" becomes available.
  final Duration resendCooldown;

  /// Biometrics are asked for again when the app returns from the
  /// background after this long.
  final Duration relockAfter;

  /// Offer "Get a call" (MSG91 retry channel 4). Only turn on when voice is
  /// enabled in the widget.
  final bool voiceRetryEnabled;

  final String countryCode;

  factory AuthConfig.fromEnvironment() => const AuthConfig(
        otpLength: int.fromEnvironment('OTP_LENGTH', defaultValue: 4),
        resendCooldown: Duration(seconds: int.fromEnvironment('OTP_RESEND_SECONDS', defaultValue: 30)),
        relockAfter: Duration(minutes: int.fromEnvironment('BIOMETRIC_RELOCK_MINUTES', defaultValue: 5)),
        voiceRetryEnabled: bool.fromEnvironment('OTP_VOICE_RETRY'),
      );
}

/// MSG91 OTP Widget credentials (built in, overridable at build time). The Authkey is deliberately absent: it is
/// only ever used server-side, to verify the access token.
class Msg91Config {
  const Msg91Config({required this.widgetId, required this.tokenAuth});

  final String widgetId;
  final String tokenAuth;

  // Built-in credentials; `--dart-define` still overrides them.
  static const _widgetId = '366878723054383834313732';
  static const _tokenAuth = '564050TGxGJGXp2f6a8c88f6P1';

  factory Msg91Config.fromEnvironment() => const Msg91Config(
        widgetId: String.fromEnvironment('MSG91_WIDGET_ID', defaultValue: _widgetId),
        tokenAuth: String.fromEnvironment('MSG91_TOKEN_AUTH', defaultValue: _tokenAuth),
      );

  /// Names of the `--dart-define` values that were not supplied.
  List<String> get missing => [
        if (widgetId.isEmpty) 'MSG91_WIDGET_ID',
        if (tokenAuth.isEmpty) 'MSG91_TOKEN_AUTH',
      ];
}

/// Development switch: replaces MSG91 with an on-device fake that accepts
/// any code except `0000`, so the app can be demoed without credentials.
const bool useFakeOtp = bool.fromEnvironment('MSG91_FAKE');

/// Use the real Firebase backend (customers and staff sign in against
/// `driveon-charter`). Off by default so builds keep working with the
/// on-device stand-in until the sign-in function is deployed.
const bool useFirebase = bool.fromEnvironment('USE_FIREBASE');

/// Point Firebase at local emulators on this host (`127.0.0.1` on a desktop
/// or iOS simulator, `10.0.2.2` on an Android emulator). Empty = the real project.
const String firebaseEmulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
