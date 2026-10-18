import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/app_info.dart';

/// The name on the home screen is set outside Dart, so these read the native
/// files and fail if they ever drift from the name the app shows.
void main() {
  test('the Android launcher label is the app name', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(RegExp(r'android:label="([^"]*)"').firstMatch(manifest)!.group(1), appName);
  });

  test('the iOS display name and bundle name are the app name', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    String valueOf(String key) => RegExp('<key>$key</key>\\s*<string>([^<]*)</string>').firstMatch(plist)!.group(1)!;
    expect(valueOf('CFBundleDisplayName'), appName);
    expect(valueOf('CFBundleName'), appName);
  });

  test('no screen still spells the name differently', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      // The only place the one-word form may appear is the app's own class name.
      final withoutClass = text.replaceAll('CharterBookingApp', '');
      if (withoutClass.contains('CharterBooking')) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });
}
