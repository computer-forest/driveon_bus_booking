import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/features/customer/screens/notification_preferences_screen.dart';
import 'package:charter_booking_ui/features/customer/screens/profile_screen.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<MockBackend> pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final backend = MockBackend();
  await tester.pumpWidget(ProviderScope(
    overrides: [mockBackendProvider.overrideWithValue(backend)],
    child: MaterialApp(theme: AppTheme.light, home: home),
  ));
  await settle(tester);
  return backend;
}

void main() {
  testWidgets('everything is on until the customer switches something off',
      (tester) async {
    await pump(tester, const NotificationPreferencesScreen());
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches, hasLength(2));
    expect(switches.every((s) => s.value), isTrue);
  });

  testWidgets('switching a choice off is saved, and only that one changes',
      (tester) async {
    final backend = await pump(tester, const NotificationPreferencesScreen());
    await tester.tap(find.byType(Switch).first);
    await settle(tester);
    expect(backend.pushPrefs.value.reminders, isFalse);
    expect(backend.pushPrefs.value.tripUpdates, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);

    await tester.tap(find.byType(Switch).first);
    await settle(tester);
    expect(backend.pushPrefs.value.reminders, isTrue);
  });

  testWidgets('the screen says what is always sent', (tester) async {
    await pump(tester, const NotificationPreferencesScreen());
    expect(find.textContaining('always sent'), findsOneWidget);
  });

  testWidgets('the profile tile opens it', (tester) async {
    await pump(tester, const ProfileScreen());
    await tester.ensureVisible(find.text('Notification preferences'));
    await settle(tester);
    await tester.tap(find.text('Notification preferences'));
    await settle(tester);
    expect(find.text('Phone alerts'), findsOneWidget);
  });
}
