import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Where this phone's push token comes from. Behind an interface so the
/// registration logic can be tested without a device.
abstract class PushTokenSource {
  /// Asks the person for permission to show notifications; false if refused.
  Future<bool> requestPermission();
  Future<String?> token();
  Stream<String> get onRefresh;
  Future<void> deleteToken();
}

class FirebaseTokenSource implements PushTokenSource {
  FirebaseTokenSource([FirebaseMessaging? messaging]) : _m = messaging ?? FirebaseMessaging.instance;
  final FirebaseMessaging _m;

  @override
  Future<bool> requestPermission() async {
    final settings = await _m.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() => _m.getToken();

  @override
  Stream<String> get onRefresh => _m.onTokenRefresh;

  @override
  Future<void> deleteToken() => _m.deleteToken();
}

/// Registers this phone to receive the signed-in person's push notifications
/// and forgets it on sign-out. A phone that cannot get a token (no
/// permission, no Google services, an iPhone without push set up) simply
/// receives nothing: the in-app inbox still shows everything.
abstract class PushService {
  Future<void> register(String uid);
  Future<void> unregister();
}

class NoopPushService implements PushService {
  const NoopPushService();

  @override
  Future<void> register(String uid) async {}

  @override
  Future<void> unregister() async {}
}

class DevicePushService implements PushService {
  DevicePushService(this._db, this._source, {String Function()? platform}) : _platform = platform ?? _defaultPlatform;

  final FirebaseFirestore _db;
  final PushTokenSource _source;
  final String Function() _platform;

  String? _uid;
  String? _token;
  StreamSubscription<String>? _refresh;

  static String _defaultPlatform() {
    if (kIsWeb) return 'web';
    return Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other');
  }

  Future<void> _save(String uid, String token) =>
      _db.doc('users/$uid/devices/$token').set({'platform': _platform(), 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> register(String uid) async {
    if (_uid == uid && _token != null) return; // already registered for this person
    try {
      if (_uid != null && _uid != uid) await unregister(); // a different person signed in on this phone
      if (!await _source.requestPermission()) return;
      final token = await _source.token();
      if (token == null || token.isEmpty) return;
      _uid = uid;
      _token = token;
      await _save(uid, token);
      await _refresh?.cancel();
      _refresh = _source.onRefresh.listen((fresh) async {
        final old = _token;
        _token = fresh;
        try {
          await _save(uid, fresh);
          if (old != null && old != fresh) await _db.doc('users/$uid/devices/$old').delete();
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('Push registration skipped: $e');
    }
  }

  @override
  Future<void> unregister() async {
    final uid = _uid;
    final token = _token;
    _uid = null;
    _token = null;
    await _refresh?.cancel();
    _refresh = null;
    try {
      if (uid != null && token != null) await _db.doc('users/$uid/devices/$token').delete();
      await _source.deleteToken();
    } catch (_) {
      // Best effort: the server also drops tokens that stop working.
    }
  }
}
