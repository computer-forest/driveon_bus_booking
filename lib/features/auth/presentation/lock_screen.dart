import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_info.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../data/providers.dart';
import '../data/auth_messages.dart';
import '../data/biometric_service.dart';

/// Shown over the app while a signed-in customer has biometric unlock on.
/// It prompts straight away; cancelling leaves the Unlock button to retry.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked, required this.onSignedOut});

  final VoidCallback onUnlocked;
  final VoidCallback onSignedOut;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await ref.read(biometricSettingsProvider).prompt('Unlock $appName');
    if (!mounted) return;
    switch (outcome) {
      case BiometricOutcome.success:
        widget.onUnlocked();
        return;
      case BiometricOutcome.cancelled:
        setState(() => _busy = false);
      case BiometricOutcome.lockedOut:
      case BiometricOutcome.notEnrolled:
      case BiometricOutcome.unavailable:
        // Biometrics can no longer protect this session: start over with OTP.
        await _useOtp(AuthMessages.forBiometric(outcome));
    }
  }

  Future<void> _useOtp(String? message) async {
    await ref.read(authRepositoryProvider).signOut();
    ref.read(authNoticeProvider.notifier).show(message);
    widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: AppRadius.containerRadius),
                child: const Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(appName, style: textTheme.displaySmall?.copyWith(fontSize: 24)),
              const SizedBox(height: AppSpacing.xxl),
              const Icon(Icons.fingerprint_rounded, size: 56, color: AppColors.primary),
              const SizedBox(height: AppSpacing.md),
              Text('Locked', style: textTheme.bodyMedium),
              const Spacer(),
              PrimaryButton(label: 'Unlock', loading: _busy, onPressed: _busy ? null : _unlock),
              const SizedBox(height: AppSpacing.md),
              TextButton(onPressed: _busy ? null : () => _useOtp(null), child: const Text('Use OTP instead')),
            ],
          ),
        ),
      ),
    );
  }
}
