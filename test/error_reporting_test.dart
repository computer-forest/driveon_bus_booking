import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/diagnostics/error_reporting.dart';

class FakeReporter implements ErrorReporter {
  final List<(Object, StackTrace?, bool)> reported = [];

  @override
  void record(Object error, StackTrace? stack, {required bool fatal}) => reported.add((error, stack, fatal));
}

void main() {
  late FlutterExceptionHandler? originalFlutter;
  late ErrorCallback? originalPlatform;

  setUp(() {
    originalFlutter = FlutterError.onError;
    originalPlatform = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = originalFlutter;
    PlatformDispatcher.instance.onError = originalPlatform;
  });

  test('a Flutter error is reported with its stack, and the earlier handler still runs', () {
    var earlierRan = false;
    FlutterError.onError = (_) => earlierRan = true;
    final reporter = FakeReporter();
    installErrorReporting(reporter);

    final stack = StackTrace.current;
    FlutterError.onError!(FlutterErrorDetails(exception: StateError('boom'), stack: stack));

    expect(reporter.reported, hasLength(1));
    expect(reporter.reported.single.$1, isA<StateError>());
    expect(reporter.reported.single.$2, stack);
    expect(reporter.reported.single.$3, isTrue);
    expect(earlierRan, isTrue);
  });

  test('an error outside Flutter (async, platform) is reported and counted as handled', () {
    PlatformDispatcher.instance.onError = null;
    final reporter = FakeReporter();
    installErrorReporting(reporter);

    final handled = PlatformDispatcher.instance.onError!(ArgumentError('late'), StackTrace.current);

    expect(handled, isTrue);
    expect(reporter.reported.single.$1, isA<ArgumentError>());
  });

  test('an earlier platform handler decides whether the error counts as handled', () {
    PlatformDispatcher.instance.onError = (_, __) => false;
    final reporter = FakeReporter();
    installErrorReporting(reporter);
    expect(PlatformDispatcher.instance.onError!(Exception('x'), StackTrace.current), isFalse);
    expect(reporter.reported, hasLength(1));
  });
}
