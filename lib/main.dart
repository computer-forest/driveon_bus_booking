import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'features/auth/data/auth_config.dart';
import 'features/auth/data/biometric_service.dart';
import 'features/auth/data/msg91_otp_service.dart';
import 'features/auth/data/secure_store.dart';
import 'features/auth/presentation/auth_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final msg91 = Msg91Config.fromEnvironment();
  if (!useFakeOtp && msg91.missing.isNotEmpty) {
    runApp(_ConfigErrorApp(missing: msg91.missing));
    return;
  }

  runApp(ProviderScope(
    overrides: [
      authConfigProvider.overrideWithValue(AuthConfig.fromEnvironment()),
      secureStoreProvider.overrideWithValue(const FlutterSecureStore()),
      biometricServiceProvider.overrideWith((ref) => LocalAuthBiometricService()),
      otpServiceProvider.overrideWith((ref) => useFakeOtp ? FakeOtpService() : Msg91OtpService(msg91)),
    ],
    child: const CharterBookingApp(),
  ));
}

class CharterBookingApp extends ConsumerWidget {
  const CharterBookingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Charter Booking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => AuthGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Shown instead of the app when a build was made without the MSG91
/// widget credentials, so the problem is obvious rather than a failed OTP.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp({required this.missing});

  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Sign-in is not configured', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 12),
                Text(
                  'This build is missing: ${missing.join(', ')}.\n\n'
                  'Run with --dart-define=MSG91_WIDGET_ID=... --dart-define=MSG91_TOKEN_AUTH=... '
                  '(or --dart-define=MSG91_FAKE=true for a demo without SMS).',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
