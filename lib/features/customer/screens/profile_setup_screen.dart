import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import 'biometric_pin_setup_screen.dart';

/// First-sign-in only (AUTH-04): the customer supplies name and email,
/// both editable later from the profile screen.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
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
              Text('A couple of details', style: textTheme.displaySmall?.copyWith(fontSize: 24)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "So Admin knows who they're calling to confirm your trip.",
                style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              LabeledField(label: 'Full name', controller: _nameController, hint: 'e.g. Rohan Deshmukh'),
              const SizedBox(height: AppSpacing.lg),
              LabeledField(
                label: 'Email',
                controller: _emailController,
                hint: 'e.g. rohan@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Continue',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BiometricPinSetupScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
