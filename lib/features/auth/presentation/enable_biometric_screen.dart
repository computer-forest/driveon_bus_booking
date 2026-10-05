import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../data/providers.dart';
import '../data/auth_messages.dart';
import '../data/biometric_service.dart';

/// Last step of first sign-in. Offered once, and only on a phone that has a
/// fingerprint or face enrolled; otherwise the customer goes straight in.
class EnableBiometricScreen extends ConsumerStatefulWidget {
  const EnableBiometricScreen({super.key});

  @override
  ConsumerState<EnableBiometricScreen> createState() => _EnableBiometricScreenState();
}

class _EnableBiometricScreenState extends ConsumerState<EnableBiometricScreen> {
  bool _checking = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  /// Marks first-sign-in complete; the router then moves the customer into
  /// the app on its own.
  Future<void> _finish() => ref.read(authRepositoryProvider).completeOnboarding();

  Future<void> _decide() async {
    final settings = ref.read(biometricSettingsProvider);
    final alreadyChose = await settings.decision() != null;
    final availability = await settings.availability();
    if (!mounted) return;
    if (alreadyChose || availability != BiometricAvailability.available) {
      await _finish();
    } else {
      setState(() => _checking = false);
    }
  }

  Future<void> _enable() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    final outcome = await ref.read(biometricSettingsProvider).enable();
    if (!mounted) return;
    setState(() => _working = false);
    if (outcome == BiometricOutcome.success) {
      await _finish();
      return;
    }
    final message = AuthMessages.forBiometric(outcome);
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _notNow() async {
    await ref.read(biometricSettingsProvider).disable();
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: AppRadius.containerRadius),
                child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 38),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Unlock with fingerprint or Face ID next time', style: textTheme.displaySmall?.copyWith(fontSize: 24)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "You won't need an OTP again on this phone. Your phone's PIN or pattern works too if the fingerprint doesn't.",
                style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              PrimaryButton(label: 'Enable', loading: _working, onPressed: _working ? null : _enable),
              const SizedBox(height: AppSpacing.md),
              Center(child: TextButton(onPressed: _working ? null : _notNow, child: const Text('Not now'))),
            ],
          ),
        ),
      ),
    );
  }
}
