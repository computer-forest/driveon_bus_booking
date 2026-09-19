import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_gradients.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/app_buttons.dart';
import 'admin/screens/admin_login_screen.dart';
import 'customer/screens/onboarding_screen.dart';

/// Not part of the product — a single switch used only to preview both
/// shells from one build while the app has no real session yet. Phase 1
/// replaces this entirely with real auth-driven routing.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppGradients.hero,
                  borderRadius: AppRadius.heroRadius,
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 10)),
                  ],
                ),
                child: const Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'PROTOTYPE PREVIEW',
                style: textTheme.labelMedium?.copyWith(color: AppColors.textTertiary, letterSpacing: 0.4),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Choose an experience', style: textTheme.displaySmall),
              const SizedBox(height: AppSpacing.xxxl),
              PrimaryButton(
                label: 'Continue as Customer',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: 'Continue as Admin',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
