import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../data/mock_data.dart';
import '../../../data/models.dart';

/// Every dead end offers a call or WhatsApp action (BRD design principle) —
/// this screen is the canonical human-fallback surface.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          children: [
            Row(
              children: [
                Expanded(
                  child: _actionCard(
                    context,
                    icon: Icons.call_rounded,
                    label: 'Call us',
                    subtitle: '+91 98200 00000',
                    color: AppColors.primary,
                    tint: AppColors.primaryTint,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _actionCard(
                    context,
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    subtitle: 'Usually replies in minutes',
                    color: AppColors.success,
                    tint: AppColors.successTint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionLabel('Frequently asked'),
            for (final faq in MockData.faqs) ...[
              _FaqTile(faq: faq),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Color tint,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(subtitle, style: textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.faq});
  final FaqItem faq;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.containerRadius,
      ),
      child: InkWell(
        borderRadius: AppRadius.containerRadius,
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(widget.faq.question, style: textTheme.titleSmall)),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textTertiary),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(widget.faq.answer, style: textTheme.bodyMedium),
                ),
                crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 160),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
