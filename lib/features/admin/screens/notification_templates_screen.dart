import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../data/mock_data.dart';

/// NOTIF-06: notification and email templates, editable by Admin without
/// an app release.
class NotificationTemplatesScreen extends StatelessWidget {
  const NotificationTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification & email templates')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
          itemCount: MockData.templates.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            final t = MockData.templates[i];
            return AppCard(
              onTap: () => _openEditor(context, t.name),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(t.name, style: textTheme.titleSmall)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.infoTint, borderRadius: AppRadius.tagRadius),
                        child: Text(t.channel, style: textTheme.labelSmall?.copyWith(color: AppColors.info)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Trigger: ${t.trigger}', style: textTheme.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.controlRadius),
                    child: Text(t.preview, style: textTheme.bodyMedium),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit "$name"', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Template body'),
              controller: TextEditingController(
                text: MockData.templates.firstWhere((t) => t.name == name).preview,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Save template')),
            ),
          ],
        ),
      ),
    );
  }
}
