import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController(text: '98765 43210');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.huge, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: AppRadius.containerRadius,
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Book the whole bus', style: textTheme.displaySmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No seats to pick — one vehicle, confirmed by our team.',
                style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              LabeledField(
                label: 'Mobile number',
                controller: _controller,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Continue',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OtpScreen()),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: Text(
                  'By continuing you agree to the Terms & Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
