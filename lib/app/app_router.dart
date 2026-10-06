import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/customer/screens/home_search_screen.dart';
import '../features/auth/presentation/enable_biometric_screen.dart';
import '../features/auth/presentation/mobile_number_screen.dart';
import '../features/customer/screens/onboarding_screen.dart';
import '../features/customer/screens/profile_setup_screen.dart';
import '../features/splash_screen.dart';
import 'nested_shell.dart';
import 'routes.dart';

/// Where [user] belongs. Role is decided by the account, never by the user
/// picking a shell: a signed-out visitor sees the welcome flow, a customer
/// who has not finished first-sign-in stays in it, and everyone else lands
/// in their own shell.
String destinationFor(AppUser? user) {
  if (user == null) return Routes.welcome;
  if (!user.onboarded) return Routes.welcome;
  return user.isAdmin ? Routes.admin : Routes.home;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      // The splash decides for itself when to move on, once the session
      // has been checked.
      if (state.matchedLocation == Routes.splash) return null;

      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return Routes.splash;

      final destination = destinationFor(auth.value);
      return state.matchedLocation == destination ? null : destination;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (_, __) => const _WelcomeFlow()),
      GoRoute(
        path: Routes.home,
        builder: (_, __) => const NestedNavigatorShell(home: HomeSearchScreen()),
      ),
      GoRoute(
        path: Routes.admin,
        builder: (_, __) => const NestedNavigatorShell(home: AdminDashboardScreen()),
      ),
    ],
  );
});

/// Signed-out entry and first-sign-in. A customer who is already signed in
/// but has not finished setting up (the app was closed mid-way) resumes at
/// their profile, or at the biometric offer if the profile is done. A
/// customer sent back to OTP on purpose goes straight to the mobile screen.
class _WelcomeFlow extends ConsumerWidget {
  const _WelcomeFlow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(authStateProvider).value;
    final Widget home;
    if (user != null) {
      // Staff skip the customer profile and go straight to the biometric offer.
      home = !user.isAdmin && (user.name ?? '').isEmpty ? const ProfileSetupScreen() : const EnableBiometricScreen();
    } else if (ref.read(authNoticeProvider) != null) {
      home = const MobileNumberScreen();
    } else {
      home = const OnboardingScreen();
    }
    return NestedNavigatorShell(home: home);
  }
}
