import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/contact_launcher.dart';
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
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

/// The Call / WhatsApp pair. Each number is the one staff set in the masters
/// configuration; tapping opens the phone's dialler or WhatsApp.
class ContactActions extends ConsumerWidget {
  const ContactActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).config;
    final opener = ref.watch(urlOpenerProvider);
    return Row(
      children: [
        Expanded(
          child: ContactActionCard(
            icon: Icons.call_rounded,
            label: 'Call us',
            subtitle: config.supportPhone,
            color: AppColors.primary,
            tint: AppColors.primaryTint,
            onTap: () => openOrExplain(
              context,
              opener,
              phoneUri(config.supportPhone),
              what: 'the phone',
              number: config.supportPhone,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: ContactActionCard(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            subtitle: 'Message us on WhatsApp',
            color: AppColors.success,
            tint: AppColors.successTint,
            onTap: () => openOrExplain(
              context,
              opener,
              whatsappUri(config.whatsappNumber, message: 'Hello, I need help with a bus booking.'),
              what: 'WhatsApp',
              number: config.whatsappNumber,
            ),
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
