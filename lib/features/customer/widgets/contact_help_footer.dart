import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../data/providers.dart';

/// One call-to-human action. Extracted from SupportScreen so every dead end
/// can offer the same pair (BRD design principle) without copying the card.
class ContactActionCard extends StatelessWidget {
  const ContactActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
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

/// The Call / WhatsApp pair. The number shown is the one an admin sets in
/// the masters configuration.
class ContactActions extends ConsumerWidget {
  const ContactActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).config;
    return Row(
      children: [
        Expanded(
          child: ContactActionCard(
            icon: Icons.call_rounded,
            label: 'Call us',
            subtitle: config.supportPhone,
            color: AppColors.primary,
            tint: AppColors.primaryTint,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: ContactActionCard(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            subtitle: 'Usually replies in minutes',
            color: AppColors.success,
            tint: AppColors.successTint,
          ),
        ),
      ],
    );
  }
}

/// A short message plus the Call / WhatsApp pair, for screens where the
/// customer may not find what they need in the listed options.
class ContactHelpFooter extends StatelessWidget {
  const ContactHelpFooter({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        const ContactActions(),
      ],
    );
  }
}
