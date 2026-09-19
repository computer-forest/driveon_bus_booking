import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Static legal copy screen, reused for both Terms & Conditions and the
/// Privacy Policy — content is Admin-editable in the real product (ADM-11)
/// so this is a plain, content-first reader.
class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key, required this.isTerms});

  final bool isTerms;

  static const _placeholderSections = [
    'What this covers',
    'Booking and holds',
    'Payments and cancellations',
    'Your responsibilities',
    'Data we collect',
    'Contact',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(isTerms ? 'Terms & Conditions' : 'Privacy Policy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
          children: [
            Text('Last updated 9 September 2026', style: textTheme.labelMedium),
            const SizedBox(height: AppSpacing.xl),
            for (final section in _placeholderSections) ...[
              Text(section, style: textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isTerms
                    ? 'Placeholder terms copy for "$section" — final legal text is supplied by the client before release (BRD C-05).'
                    : 'Placeholder privacy copy for "$section" — final legal text is supplied by the client before release (BRD C-05).',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ],
        ),
      ),
    );
  }
}
