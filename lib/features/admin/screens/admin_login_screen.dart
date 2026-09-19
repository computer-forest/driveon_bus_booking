import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: AppRadius.controlRadius,
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'OPERATIONS CONSOLE',
                style: textTheme.labelMedium?.copyWith(letterSpacing: 0.4),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Sign in', style: textTheme.displaySmall),
              const SizedBox(height: AppSpacing.xxxl),
              const LabeledField(label: 'Email', initialValue: 'ops@neetatravels.example'),
              const SizedBox(height: AppSpacing.lg),
              const LabeledField(label: 'Password', initialValue: '••••••••'),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Sign in',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
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
