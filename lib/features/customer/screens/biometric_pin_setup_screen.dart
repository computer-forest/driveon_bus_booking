import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import 'home_search_screen.dart';

/// AUTH-03: after first sign-in, re-entry is protected by device biometric
/// or an app PIN the customer sets here. OTP is not asked again after this.
class BiometricPinSetupScreen extends StatefulWidget {
  const BiometricPinSetupScreen({super.key});

  @override
  State<BiometricPinSetupScreen> createState() => _BiometricPinSetupScreenState();
}

class _BiometricPinSetupScreenState extends State<BiometricPinSetupScreen> {
  int _choice = 0; // 0 = biometric, 1 = PIN

  void _finish() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeSearchScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Secure your account', style: textTheme.displaySmall?.copyWith(fontSize: 24)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "You won't need to verify by OTP again on this device.",
                style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              _option(
                index: 0,
                icon: Icons.fingerprint_rounded,
                title: 'Use biometric unlock',
                subtitle: 'Face or fingerprint, whatever this device supports.',
              ),
              const SizedBox(height: AppSpacing.md),
              _option(
                index: 1,
                icon: Icons.pin_rounded,
                title: 'Set a 4-digit PIN',
                subtitle: "Use this if you'd rather not use biometrics.",
              ),
              const Spacer(),
              PrimaryButton(label: 'Continue', onPressed: _finish),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(onPressed: _finish, child: const Text('Set up later')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option({required int index, required IconData icon, required String title, required String subtitle}) {
    final selected = _choice == index;
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => setState(() => _choice = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : AppColors.surface,
          borderRadius: AppRadius.containerRadius,
          border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 1.4),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: textTheme.bodyMedium),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
