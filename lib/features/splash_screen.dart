import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/routes.dart';
import '../core/app_info.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_gradients.dart';
import '../data/providers.dart';

/// First screen shown on launch. It waits for the saved session to be
/// checked (and a moment of branding), then the router sends the user to
/// the welcome flow or straight to their own shell.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _proceed();
  }

  Future<void> _proceed() async {
    await Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 900)),
      ref.read(authRepositoryProvider).authState().first,
    ]);
    if (!mounted) return;
    context.go(Routes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                appName,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Book the whole bus',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: AppColors.primary,
    );
  }
}
