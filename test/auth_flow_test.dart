import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/features/auth/data/auth_config.dart';
import 'package:charter_booking_ui/features/auth/data/biometric_service.dart';
import 'package:charter_booking_ui/features/auth/data/msg91_otp_service.dart';
import 'package:charter_booking_ui/features/auth/data/phone.dart';
import 'package:charter_booking_ui/features/auth/data/secure_store.dart';
import 'package:charter_booking_ui/main.dart';

class FakeBiometric implements BiometricService {
  FakeBiometric({this.available = BiometricAvailability.available, List<BiometricOutcome>? outcomes})
      : outcomes = outcomes ?? [];

  BiometricAvailability available;
  final List<BiometricOutcome> outcomes;
  int prompts = 0;

  @override
  Future<BiometricAvailability> availability() async => available;

  @override
  Future<BiometricOutcome> authenticate({required String reason}) async {
    prompts++;
    return outcomes.isEmpty ? BiometricOutcome.success : outcomes.removeAt(0);
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> launch(WidgetTester tester, {required InMemorySecureStore store, required FakeBiometric biometric}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
      biometricServiceProvider.overrideWithValue(biometric),
    ],
    child: const CharterBookingApp(),
  ));
  await tester.pump(const Duration(milliseconds: 1200));
  await settle(tester);
}

/// The legal lifecycle path for leaving the app and coming back.
void goToBackgroundAndBack(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await settle(tester);
}

/// A customer who signed in on this phone earlier.
Future<InMemorySecureStore> returningCustomer({required bool biometric}) async {
  final store = InMemorySecureStore();
  await store.write(StoreKeys.sessionPhone, '9820011223');
  await store.write(StoreKeys.sessionOnboarded, 'true');
  await store.write(StoreKeys.profile('cust_919820011223'), 'Rohan Deshmukh\nr@example.com');
  await store.write(StoreKeys.biometricEnabled, biometric ? 'true' : 'false');
  return store;
}

Future<void> toOtpScreen(WidgetTester tester) async {
  await tapText(tester, 'Skip');
  await tester.enterText(find.byType(TextField), '9820011223');
  await tapText(tester, 'Continue');
}

void main() {
  group('phone numbers', () {
    test('ten digits starting 6-9 are valid, anything else says why', () {
      expect(Phone.validate('9820011223'), isNull);
      expect(Phone.validate('98200 11223'), isNull);
      expect(Phone.validate(''), contains('Enter your 10-digit'));
      expect(Phone.validate('98200'), contains('exactly 10'));
      expect(Phone.validate('1234567890'), contains('start with'));
    });

    test('the MSG91 identifier is country code plus digits, no plus', () {
      expect(Phone.identifier('98200 11223'), '919820011223');
      expect(Phone.pretty('9820011223'), '98200 11223');
    });
  });

  group('MSG91 responses', () {
    test('free-text errors are sorted into the cases the screens handle', () {
      expect(Msg91OtpService.classify('Invalid OTP').kind, OtpFailure.wrongOtp);
      expect(Msg91OtpService.classify('OTP expired').kind, OtpFailure.expired);
      expect(Msg91OtpService.classify('Retry limit reached').kind, OtpFailure.tooManyAttempts);
      expect(Msg91OtpService.classify('Exception: SocketException: Failed host lookup').kind, OtpFailure.network);
      expect(Msg91OtpService.classify('Failed to post data: 400, {"message":"Mobile number invalid"}').message,
          'Mobile number invalid');
    });
  });

  group('session on the device', () {
    test('a customer is restored on the next launch without another OTP', () async {
      final store = InMemorySecureStore();
      final first = MockAuthRepository(MockBackend(), store: store);
      await first.signInWithOtpToken(phone: '9820011223', accessToken: 't');
      await first.updateProfile(name: 'Rohan', email: 'r@example.com');
      await first.completeOnboarding();

      final relaunched = await MockAuthRepository(MockBackend(), store: store).authState().first;
      expect(relaunched?.id, 'cust_919820011223');
      expect(relaunched?.name, 'Rohan');
      expect(relaunched?.onboarded, isTrue);
    });

    test('a returning number gets its profile back but still has to choose biometrics', () async {
      final store = await returningCustomer(biometric: true);
      final auth = MockAuthRepository(MockBackend(), store: store);
      await auth.signOut();

      final user = await auth.signInWithOtpToken(phone: '9820011223', accessToken: 't');
      expect(user.name, 'Rohan Deshmukh');
      expect(user.onboarded, isFalse);
    });

    test('logging out forgets the session, the stored number and the biometric choice', () async {
      final store = await returningCustomer(biometric: true);
      final auth = MockAuthRepository(MockBackend(), store: store);
      await auth.authState().first;
      await auth.signOut();

      expect(await store.read(StoreKeys.sessionPhone), isNull);
      expect(await store.read(StoreKeys.lastPhone), isNull);
      expect(await store.read(StoreKeys.biometricEnabled), isNull);
      expect(await MockAuthRepository(MockBackend(), store: store).authState().first, isNull);
    });
  });

  group('mobile number and OTP screens', () {
    testWidgets('a bad number is explained inline and nothing is sent', (tester) async {
      await launch(tester, store: InMemorySecureStore(), biometric: FakeBiometric());
      await tapText(tester, 'Skip');

      await tester.enterText(find.byType(TextField), '1234567890');
      await tapText(tester, 'Continue');
      expect(find.text('Mobile number must start with 6, 7, 8 or 9.'), findsOneWidget);
      expect(find.text('Verify number'), findsNothing);

      await tester.enterText(find.byType(TextField), '98200');
      await tapText(tester, 'Continue');
      expect(find.text('Mobile number must be exactly 10 digits.'), findsOneWidget);
    });

    testWidgets('the number shows with its country code and can be edited', (tester) async {
      await launch(tester, store: InMemorySecureStore(), biometric: FakeBiometric());
      await toOtpScreen(tester);

      expect(find.text('Code sent to +91 98200 11223'), findsOneWidget);
      await tapText(tester, 'Edit number');
      expect(find.text('Mobile number'), findsOneWidget);
    });

    testWidgets('resend appears after the cooldown and sends a new code', (tester) async {
      await launch(tester, store: InMemorySecureStore(), biometric: FakeBiometric());
      await toOtpScreen(tester);

      expect(find.textContaining('Resend code in'), findsOneWidget);
      expect(find.text('Resend via SMS'), findsNothing);

      await tester.pump(const Duration(seconds: 31));
      expect(find.text('Resend via SMS'), findsOneWidget);
      expect(find.text('Get a call'), findsNothing); // voice is off by default

      await tapText(tester, 'Resend via SMS');
      expect(find.text('We sent you a new code.'), findsOneWidget);
      expect(find.textContaining('Resend code in'), findsOneWidget);
    });

    testWidgets('an expired code enables resend straight away', (tester) async {
      await launch(tester, store: InMemorySecureStore(), biometric: FakeBiometric());
      await toOtpScreen(tester);

      await tester.enterText(find.byType(TextField), '9999');
      await settle(tester);

      expect(find.text('This code has expired. Request a new one.'), findsOneWidget);
      expect(find.text('Resend via SMS'), findsOneWidget);
    });

    testWidgets('the code length comes from config', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [authConfigProvider.overrideWithValue(const AuthConfig(otpLength: 6))],
        child: const CharterBookingApp(),
      ));
      await tester.pump(const Duration(milliseconds: 1200));
      await settle(tester);
      await toOtpScreen(tester);

      await tester.enterText(find.byType(TextField), '1234');
      await settle(tester);
      expect(find.text('Verify & continue'), findsOneWidget); // 4 of 6 digits: not submitted yet
      await tester.enterText(find.byType(TextField), '123456');
      await settle(tester);
      expect(find.text('Rohan'), findsNothing);
      expect(find.text('A couple of details'), findsOneWidget);
    });
  });

  group('biometric offer', () {
    Future<void> signInToProfile(WidgetTester tester) async {
      await toOtpScreen(tester);
      await tester.enterText(find.byType(TextField), '1234');
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Rohan Deshmukh');
      await tester.pump();
      await tapText(tester, 'Continue');
    }

    testWidgets('Enable confirms with one prompt, saves the choice and goes home', (tester) async {
      final store = InMemorySecureStore();
      final biometric = FakeBiometric();
      await launch(tester, store: store, biometric: biometric);
      await signInToProfile(tester);

      expect(find.text('Unlock with fingerprint or Face ID next time'), findsOneWidget);
      await tapText(tester, 'Enable');

      expect(biometric.prompts, 1);
      expect(await store.read(StoreKeys.biometricEnabled), 'true');
      expect(find.text('Find a bus'), findsOneWidget);
    });

    testWidgets('Not now is remembered and goes home without a prompt', (tester) async {
      final store = InMemorySecureStore();
      final biometric = FakeBiometric();
      await launch(tester, store: store, biometric: biometric);
      await signInToProfile(tester);

      await tapText(tester, 'Not now');

      expect(biometric.prompts, 0);
      expect(await store.read(StoreKeys.biometricEnabled), 'false');
      expect(find.text('Find a bus'), findsOneWidget);
    });

    testWidgets('a phone with no biometrics enrolled skips the offer silently', (tester) async {
      final store = InMemorySecureStore();
      await launch(tester, store: store, biometric: FakeBiometric(available: BiometricAvailability.notEnrolled));
      await signInToProfile(tester);

      expect(find.text('Unlock with fingerprint or Face ID next time'), findsNothing);
      expect(find.text('Find a bus'), findsOneWidget);
      expect(await store.read(StoreKeys.biometricEnabled), isNull);
    });

    testWidgets('a failed Enable keeps the customer on the offer and says why', (tester) async {
      final store = InMemorySecureStore();
      final biometric = FakeBiometric(outcomes: [BiometricOutcome.notEnrolled]);
      await launch(tester, store: store, biometric: biometric);
      await signInToProfile(tester);

      await tapText(tester, 'Enable');

      expect(find.text('Set up fingerprint or Face ID in your phone settings first.'), findsOneWidget);
      expect(find.text('Unlock with fingerprint or Face ID next time'), findsOneWidget);
      expect(await store.read(StoreKeys.biometricEnabled), isNull);
    });
  });

  group('every later launch', () {
    testWidgets('biometrics on: the prompt appears, not OTP, and success opens the app', (tester) async {
      final biometric = FakeBiometric();
      await launch(tester, store: await returningCustomer(biometric: true), biometric: biometric);

      expect(biometric.prompts, 1);
      expect(find.text('Find a bus'), findsOneWidget);
      expect(find.text('Unlock'), findsNothing);
    });

    testWidgets('cancelling keeps the lock screen, and Unlock tries again', (tester) async {
      final biometric = FakeBiometric(outcomes: [BiometricOutcome.cancelled]);
      await launch(tester, store: await returningCustomer(biometric: true), biometric: biometric);

      expect(find.text('Unlock'), findsOneWidget);
      expect(find.text('Use OTP instead'), findsOneWidget);
      expect(find.text('Find a bus'), findsNothing);

      await tapText(tester, 'Unlock');
      expect(biometric.prompts, 2);
      expect(find.text('Find a bus'), findsOneWidget);
    });

    testWidgets('locked out: signs out and sends the customer to OTP with a message', (tester) async {
      final store = await returningCustomer(biometric: true);
      await launch(tester, store: store, biometric: FakeBiometric(outcomes: [BiometricOutcome.lockedOut]));

      expect(find.text('Biometrics are locked. Log in with OTP.'), findsOneWidget);
      expect(find.text('Mobile number'), findsOneWidget);
      expect(await store.read(StoreKeys.sessionPhone), isNull);
      expect(await store.read(StoreKeys.biometricEnabled), isNull);
    });

    testWidgets('Use OTP instead signs out and starts the OTP flow', (tester) async {
      final store = await returningCustomer(biometric: true);
      await launch(tester, store: store, biometric: FakeBiometric(outcomes: [BiometricOutcome.cancelled]));

      await tapText(tester, 'Use OTP instead');

      expect(find.text('Mobile number'), findsOneWidget);
      expect(await store.read(StoreKeys.sessionPhone), isNull);
    });

    testWidgets('biometrics off: straight in, no prompt', (tester) async {
      final biometric = FakeBiometric();
      await launch(tester, store: await returningCustomer(biometric: false), biometric: biometric);

      expect(biometric.prompts, 0);
      expect(find.text('Find a bus'), findsOneWidget);
    });

    testWidgets('coming back after the relock delay asks again; a short absence does not', (tester) async {
      final biometric = FakeBiometric();
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          secureStoreProvider.overrideWithValue(await returningCustomer(biometric: true)),
          biometricServiceProvider.overrideWithValue(biometric),
          authConfigProvider.overrideWithValue(const AuthConfig(relockAfter: Duration(minutes: 5))),
        ],
        child: const CharterBookingApp(),
      ));
      await tester.pump(const Duration(milliseconds: 1200));
      await settle(tester);
      expect(biometric.prompts, 1);

      // A quick trip to another app: no prompt.
      goToBackgroundAndBack(tester);
      await settle(tester);
      expect(biometric.prompts, 1);
    });

    testWidgets('relock after the delay brings the lock screen back over the same place', (tester) async {
      final biometric = FakeBiometric(outcomes: [BiometricOutcome.success, BiometricOutcome.cancelled]);
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          secureStoreProvider.overrideWithValue(await returningCustomer(biometric: true)),
          biometricServiceProvider.overrideWithValue(biometric),
          authConfigProvider.overrideWithValue(const AuthConfig(relockAfter: Duration.zero)),
        ],
        child: const CharterBookingApp(),
      ));
      await tester.pump(const Duration(milliseconds: 1200));
      await settle(tester);
      expect(find.text('Find a bus'), findsOneWidget);

      goToBackgroundAndBack(tester);
      await settle(tester);
      expect(biometric.prompts, 2);
      expect(find.text('Unlock'), findsOneWidget);

      await tapText(tester, 'Unlock');
      expect(find.text('Find a bus'), findsOneWidget);
    });

    testWidgets('signed out: the sign-in flow', (tester) async {
      await launch(tester, store: InMemorySecureStore(), biometric: FakeBiometric());
      expect(find.text('Skip'), findsOneWidget);
    });
  });

  group('profile toggle', () {
    testWidgets('turning it on runs the prompt first; turning it off clears the flag', (tester) async {
      final store = await returningCustomer(biometric: false);
      final biometric = FakeBiometric();
      await launch(tester, store: store, biometric: biometric);

      await tapText(tester, 'Profile');
      await tester.tap(find.byType(Switch));
      await settle(tester);
      expect(biometric.prompts, 1);
      expect(await store.read(StoreKeys.biometricEnabled), 'true');

      await tester.tap(find.byType(Switch));
      await settle(tester);
      expect(await store.read(StoreKeys.biometricEnabled), 'false');
    });

    testWidgets('with nothing enrolled it explains what to do', (tester) async {
      final store = await returningCustomer(biometric: false);
      await launch(tester, store: store, biometric: FakeBiometric(available: BiometricAvailability.notEnrolled));

      await tapText(tester, 'Profile');
      await tester.tap(find.byType(Switch));
      await settle(tester);

      expect(find.text('Set up fingerprint or Face ID in your phone settings first.'), findsOneWidget);
      expect(await store.read(StoreKeys.biometricEnabled), 'false');
    });
  });
}
