import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../role_select_screen.dart';

/// AUTH-09: customer-initiated account deletion. Personal data is erased
/// and past bookings anonymised; financial records are retained.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(color: AppColors.urgentTint, borderRadius: AppRadius.containerRadius),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_rounded, color: AppColors.urgent, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'This cannot be undone. Your profile and personal data are erased immediately.',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.urgent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('What happens', style: textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              _point('Your name, email and saved locations are permanently erased.'),
              _point('Past bookings are anonymised — trip records remain for operational history.'),
              _point('Financial records are retained as required for accounting.'),
              _point("You'll need to register again with a new OTP to use CharterBooking in future."),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _understood = !_understood),
                child: Row(
                  children: [
                    Icon(
                      _understood ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      color: _understood ? AppColors.urgent : AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('I understand this is permanent', style: textTheme.bodyMedium)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _understood
                      ? () => Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                            (route) => false,
                          )
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.urgent,
                    side: const BorderSide(color: AppColors.urgent),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Delete my account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _point(String text) {
    return Builder(builder: (context) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Icon(Icons.circle, size: 4, color: AppColors.textTertiary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
    });
  }
}
