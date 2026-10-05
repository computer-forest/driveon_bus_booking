import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';

import 'auth_config.dart';
import 'auth_messages.dart';

enum OtpFailure { network, wrongOtp, expired, tooManyAttempts, other }

class OtpException implements Exception {
  const OtpException(this.kind, this.message);

  final OtpFailure kind;

  /// Already worded for the customer.
  final String message;

  @override
  String toString() => 'OtpException($kind): $message';
}

/// MSG91 retry channels.
class OtpChannel {
  OtpChannel._();
  static const sms = 11;
  static const voice = 4;
  static const whatsApp = 12;
  static const email = 3;
}

abstract class OtpService {
  /// [identifier] is country code + number, digits only. Returns the request id.
  Future<String> send(String identifier);

  /// Returns the MSG91 access token, which the server then verifies.
  Future<String> verify({required String reqId, required String otp});

  Future<void> retry({required String reqId, int channel = OtpChannel.sms});
}

/// MSG91 OTP Widget. The response shape is not formally documented, so every
/// read is defensive and the raw response is logged in debug builds.
class Msg91OtpService implements OtpService {
  Msg91OtpService(Msg91Config config) {
    OTPWidget.initializeWidget(config.widgetId, config.tokenAuth);
  }

  @override
  Future<String> send(String identifier) async {
    final res = await _call('sendOTP', () => OTPWidget.sendOTP({'identifier': identifier}));
    return _successMessage(res, fallback: 'Could not send the code. Please try again.');
  }

  @override
  Future<String> verify({required String reqId, required String otp}) async {
    final res = await _call('verifyOTP', () => OTPWidget.verifyOTP({'reqId': reqId, 'otp': otp}), redact: true);
    return _successMessage(res, fallback: AuthMessages.wrongOtp);
  }

  @override
  Future<void> retry({required String reqId, int channel = OtpChannel.sms}) async {
    final res = await _call('retryOTP', () => OTPWidget.retryOTP({'reqId': reqId, 'retryChannel': channel}));
    _successMessage(res, fallback: 'Could not resend the code. Please try again.');
  }

  Future<Map<String, dynamic>?> _call(
    String name,
    Future<Map<String, dynamic>?> Function() request, {
    bool redact = false,
  }) async {
    try {
      final res = await request().timeout(const Duration(seconds: 20));
      if (kDebugMode) debugPrint('MSG91 $name → ${redact ? _redacted(res) : res}');
      return res;
    } on TimeoutException {
      throw const OtpException(OtpFailure.network, AuthMessages.noInternet);
    } catch (e) {
      if (kDebugMode) debugPrint('MSG91 $name failed: $e');
      throw _fromText(e.toString());
    }
  }

  static Object? _redacted(Map<String, dynamic>? res) =>
      res == null ? null : {...res, if (res['type'] == 'success') 'message': '<access token>'};

  /// `message` of a `type: success` response, or an [OtpException].
  static String _successMessage(Map<String, dynamic>? res, {required String fallback}) {
    final type = res?['type']?.toString().toLowerCase();
    final message = res?['message']?.toString() ?? '';
    if (type == 'success' && message.isNotEmpty) return message;
    throw _fromText(message.isEmpty ? fallback : message, fallback: fallback);
  }

  /// Sorts a free-text MSG91 or transport error into one of our cases.
  @visibleForTesting
  static OtpException classify(String text, {String? fallback}) => _fromText(text, fallback: fallback);

  static OtpException _fromText(String text, {String? fallback}) {
    final t = text.toLowerCase();
    if (RegExp(r'socketexception|failed host lookup|clientexception|timeout|network|connection').hasMatch(t)) {
      return const OtpException(OtpFailure.network, AuthMessages.noInternet);
    }
    if (t.contains('expire')) return const OtpException(OtpFailure.expired, AuthMessages.expiredOtp);
    if (RegExp(r'too many|retry limit|retries|max(imum)? (attempt|limit)|attempts? (limit|exceed)|limit (reached|exceed)').hasMatch(t)) {
      return OtpException(OtpFailure.tooManyAttempts, _plain(text));
    }
    if (RegExp(r'otp|code').hasMatch(t) && RegExp(r'invalid|incorrect|wrong|mismatch|not match').hasMatch(t)) {
      return const OtpException(OtpFailure.wrongOtp, AuthMessages.wrongOtp);
    }
    return OtpException(OtpFailure.other, fallback ?? _plain(text));
  }

  /// The SDK wraps errors as `Exception('Failed to post data: 400, {...}')`;
  /// pull the human message out when there is one.
  static String _plain(String text) {
    final m = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(text);
    return m?.group(1) ?? text.replaceFirst('Exception: ', '');
  }
}

/// Stand-in used when `MSG91_FAKE=true` and in tests. Accepts any code
/// except `0000` (wrong) and `9999` (expired).
class FakeOtpService implements OtpService {
  FakeOtpService({this.latency = Duration.zero});

  final Duration latency;
  int _counter = 0;

  @override
  Future<String> send(String identifier) async {
    await Future<void>.delayed(latency);
    return 'fake-req-${++_counter}';
  }

  @override
  Future<String> verify({required String reqId, required String otp}) async {
    await Future<void>.delayed(latency);
    if (otp == '0000') throw const OtpException(OtpFailure.wrongOtp, AuthMessages.wrongOtp);
    if (otp == '9999') throw const OtpException(OtpFailure.expired, AuthMessages.expiredOtp);
    return 'fake-access-token-$reqId';
  }

  @override
  Future<void> retry({required String reqId, int channel = OtpChannel.sms}) async {
    await Future<void>.delayed(latency);
  }
}
