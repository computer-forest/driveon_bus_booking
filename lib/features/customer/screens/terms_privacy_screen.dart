import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/async_body.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';

/// The Terms & Conditions or the Privacy Policy, read from the text staff
/// keep in the app (ADM-11), so the wording changes without a new release.
/// Until staff have written it, the screen says so plainly rather than
/// showing invented copy.
class TermsPrivacyScreen extends ConsumerWidget {
  const TermsPrivacyScreen({super.key, required this.isTerms});

  final bool isTerms;

  LegalKind get _kind => isTerms ? LegalKind.terms : LegalKind.privacy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_kind.title)),
      body: SafeArea(
        child: AsyncBody<LegalDocument?>(
          value: ref.watch(legalProvider(_kind)),
          builder: (doc) {
            if (doc == null || doc.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'Our ${_kind.title} are being finalised. If you need them now, contact support from the Profile tab.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                ),
              );
            }
            final updated = doc.updatedAt;
            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
              children: [
                if (updated != null) ...[
                  Text('Last updated ${AppDateFormat.dayMonthYear(updated)}', style: textTheme.labelMedium),
                  const SizedBox(height: AppSpacing.xl),
                ],
                for (final section in doc.sections) ...[
                  if (section.heading.isNotEmpty) ...[
                    Text(section.heading, style: textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Text(section.body, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
