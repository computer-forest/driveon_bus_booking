import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/guarded_write.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';

/// Lets a customer switch off the optional phone alerts. Fares, booking
/// confirmations, cancellations and bus changes are always sent, and every
/// message stays in the in-app inbox either way.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref, PushPrefs next) =>
      guardedWrite(
          context, () => ref.read(pushPrefsRepositoryProvider).save(next));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final prefs = ref.watch(pushPrefsProvider).value ?? const PushPrefs();
    return Scaffold(
      appBar: AppBar(title: const Text('Notification preferences')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          children: [
            const SectionLabel('Phone alerts'),
            _row(
              textTheme,
              title: 'Hold reminders',
              subtitle:
                  'When a bus is held for you, about to be released, or released.',
              value: prefs.reminders,
              onChanged: (v) =>
                  _save(context, ref, prefs.copyWith(reminders: v)),
            ),
            _row(
              textTheme,
              title: 'Trip updates',
              subtitle:
                  'When your trip starts, finishes, and your booking is fully paid.',
              value: prefs.tripUpdates,
              onChanged: (v) =>
                  _save(context, ref, prefs.copyWith(tripUpdates: v)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Fare quotes, booking confirmations, cancellations, refunds and bus changes '
              'are always sent, because you need them. Switched-off messages still appear in '
              'your notifications inside the app.',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    TextTheme textTheme, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
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
            Switch(
                value: value,
                activeThumbColor: AppColors.primary,
                onChanged: onChanged),
          ],
        ),
      );
}
