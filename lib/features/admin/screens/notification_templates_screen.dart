import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/guarded_write.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';

/// NOTIF-06: notification and email templates, editable by Admin without
/// an app release.
class NotificationTemplatesScreen extends ConsumerWidget {
  const NotificationTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final templates = ref.watch(templatesProvider).items;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification & email templates')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
          itemCount: templates.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            final t = templates[i];
            return AppCard(
              onTap: () => _openEditor(context, t),
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

  void _openEditor(BuildContext context, MessageTemplate template) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TemplateEditor(template: template),
    );
  }
}

class _TemplateEditor extends ConsumerStatefulWidget {
  const _TemplateEditor({required this.template});

  final MessageTemplate template;

  @override
  ConsumerState<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends ConsumerState<_TemplateEditor> {
  late final _body = TextEditingController(text: widget.template.preview);

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await guardedWrite(
      context,
      () => ref.read(templateRepositoryProvider).save(widget.template.copyWith(preview: _body.text.trim())),
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text('Edit "${widget.template.name}"', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _body,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Template body'),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('Save template')),
          ),
        ],
      ),
    );
  }
}
