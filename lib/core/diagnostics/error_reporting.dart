
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Where crashes and unexpected errors are sent so they can be seen and fixed.
/// Behind an interface so the wiring can be tested without Firebase.
///
/// Reports carry the error and where it happened, never who it happened to:
/// no user id, name or phone number is attached.
abstract class ErrorReporter {
  void record(Object error, StackTrace? stack, {required bool fatal});
}

class CrashlyticsReporter implements ErrorReporter {
  CrashlyticsReporter([FirebaseCrashlytics? crashlytics]) : _c = crashlytics ?? FirebaseCrashlytics.instance;
  final FirebaseCrashlytics _c;

  @override
  void record(Object error, StackTrace? stack, {required bool fatal}) {
    _c.recordError(error, stack, fatal: fatal);
  }

  /// Developers' own debug runs should not fill the dashboard.
  Future<void> enableCollection(bool enabled) => _c.setCrashlyticsCollectionEnabled(enabled);
}

/// Sends every uncaught Flutter and platform error to [reporter], and still
/// lets the previous handlers run (so errors keep printing in debug builds).
void installErrorReporting(ErrorReporter reporter) {
  final previousFlutter = FlutterError.onError;
  FlutterError.onError = (details) {
    reporter.record(details.exception, details.stack, fatal: true);
    previousFlutter?.call(details);
  };

  final previousPlatform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.record(error, stack, fatal: true);
    return previousPlatform?.call(error, stack) ?? true;
  };
}
