import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/providers.dart';

/// ADM-13: every privileged action is written to an audit log with actor,
/// timestamp and reason.
class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider)();
    final entries = ref.watch(auditLogProvider).items.toList()..sort((a, b) => b.at.compareTo(a.at));
    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];
            final isLast = i == entries.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      ),
                      if (!isLast) Expanded(child: Container(width: 1.4, color: AppColors.border)),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.action, style: textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(entry.detail, style: textTheme.bodyMedium),
                          const SizedBox(height: 4),
                          Text('${entry.actor} · ${AppDateFormat.dayAndTime(entry.at, now)}', style: textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
