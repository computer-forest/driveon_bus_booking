import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/data/repositories/repositories.dart';
import 'package:charter_booking_ui/features/customer/screens/edit_profile_screen.dart';
import 'package:charter_booking_ui/features/customer/screens/profile_screen.dart';

const user = AppUser(
  id: 'cust_919820011223',
  role: UserRole.customer,
  name: 'Rohan Deshmukh',
  email: 'rohan@example.com',
  phone: '98200 11223',
  onboarded: true,
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save changes'));
  await settle(tester);
  await tester.tap(find.text('Save changes'));
  await settle(tester);
}

class _OfflineAuth extends MockAuthRepository {
  _OfflineAuth(super.b);

  @override
  Future<void> updateProfile({required String name, required String email}) =>
      throw const AuthException('No internet connection. Check your connection and try again.');
}

Future<MockBackend> pump(WidgetTester tester, Widget home, {bool offline = false}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final backend = MockBackend()..user.value = user;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      mockBackendProvider.overrideWithValue(backend),
      if (offline) authRepositoryProvider.overrideWith((ref) => _OfflineAuth(backend)),
    ],
    child: MaterialApp(theme: AppTheme.light, home: home),
  ));
  await settle(tester);
  return backend;
}

void main() {
  testWidgets('tapping the profile card opens the editor, filled with the current details', (tester) async {
    await pump(tester, const ProfileScreen());
    await tester.tap(find.text('Rohan Deshmukh'));
    await settle(tester);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text, 'Rohan Deshmukh');
    expect(tester.widget<TextFormField>(find.byType(TextFormField).last).controller!.text, 'rohan@example.com');
    expect(find.text('+91 98200 11223'), findsOneWidget);
  });

  testWidgets('changing the name and email saves them and the profile shows the new ones', (tester) async {
    final backend = await pump(tester, const ProfileScreen());
    await tester.tap(find.text('Rohan Deshmukh'));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).first, '  Rohan D. Deshmukh ');
    await tester.enterText(find.byType(TextFormField).last, 'rohan.d@example.com');
    await save(tester);
    await settle(tester);

    expect(backend.user.value?.name, 'Rohan D. Deshmukh');
    expect(backend.user.value?.email, 'rohan.d@example.com');
    expect(find.text('Profile updated.'), findsOneWidget);
    expect(find.text('Rohan D. Deshmukh'), findsOneWidget);
  });

  testWidgets('the number is shown but cannot be edited, and the account id is untouched', (tester) async {
    final backend = await pump(tester, const EditProfileScreen(user: user));
    expect(find.byType(TextFormField), findsNWidgets(2));
    await save(tester);
    await settle(tester);
    expect(backend.user.value?.phone, '98200 11223');
    expect(backend.user.value?.id, 'cust_919820011223');
  });

  testWidgets('an empty name is refused with a reason and nothing is saved', (tester) async {
    final backend = await pump(tester, const EditProfileScreen(user: user));
    await tester.enterText(find.byType(TextFormField).first, '   ');
    await save(tester);
    await settle(tester);
    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(backend.user.value?.name, 'Rohan Deshmukh');
  });

  testWidgets('an email that is not an address is refused, an empty one is allowed', (tester) async {
    final backend = await pump(tester, const EditProfileScreen(user: user));
    await tester.enterText(find.byType(TextFormField).last, 'not-an-email');
    await save(tester);
    await settle(tester);
    expect(find.textContaining('does not look right'), findsOneWidget);
    expect(backend.user.value?.email, 'rohan@example.com');

    await tester.enterText(find.byType(TextFormField).last, '');
    await save(tester);
    await settle(tester);
    expect(backend.user.value?.email, '');
  });

  testWidgets('a save that fails explains why and keeps what was typed', (tester) async {
    await pump(tester, const EditProfileScreen(user: user), offline: true);
    await tester.enterText(find.byType(TextFormField).first, 'New Name');
    await save(tester);
    await settle(tester);
    expect(find.textContaining('No internet connection'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text, 'New Name');
  });
}
