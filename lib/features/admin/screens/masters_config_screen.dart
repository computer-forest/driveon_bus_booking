import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../data/mock_data.dart';
import 'notification_templates_screen.dart';

/// ADM-11: cities/areas, capacities, hold duration, buffer defaults,
/// support/WhatsApp numbers, Terms & Privacy content, template access.
class MastersConfigScreen extends StatefulWidget {
  const MastersConfigScreen({super.key});

  @override
  State<MastersConfigScreen> createState() => _MastersConfigScreenState();
}

class _MastersConfigScreenState extends State<MastersConfigScreen> {
  double _holdMinutes = 30;
  double _preBuffer = 45;
  double _postBuffer = 45;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Masters & configuration')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
          children: [
            const SectionLabel('Hold & buffer defaults'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sliderRow('Hold duration', _holdMinutes, 10, 60, '${_holdMinutes.round()} min',
                      (v) => setState(() => _holdMinutes = v)),
                  const HairlineDivider(),
                  _sliderRow('Pre-trip buffer', _preBuffer, 0, 120, '${_preBuffer.round()} min',
                      (v) => setState(() => _preBuffer = v)),
                  const HairlineDivider(),
                  _sliderRow('Post-trip buffer', _postBuffer, 0, 120, '${_postBuffer.round()} min',
                      (v) => setState(() => _postBuffer = v)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Per-bus overrides are set from that bus\'s record. Buffer is never computed automatically.',
                style: textTheme.labelMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Cities & areas', trailing: _AddChip()),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: {for (final l in MockData.locations) l.city}.map((city) {
                return Chip(label: Text(city), onDeleted: () {});
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Capacity list'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: const [17, 20, 27, 30, 35, 40].map((c) => Chip(label: Text('$c seater'))).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Support & advance'),
            const LabeledField(label: 'Support phone number', initialValue: '+91 98200 00000'),
            const SizedBox(height: AppSpacing.lg),
            const LabeledField(label: 'WhatsApp number', initialValue: '+91 98200 00000'),
            const SizedBox(height: AppSpacing.lg),
            const LabeledField(label: 'Default advance %', initialValue: '25'),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Content'),
            _linkRow(context, Icons.description_outlined, 'Terms & Conditions'),
            _linkRow(context, Icons.privacy_tip_outlined, 'Privacy Policy'),
            _linkRow(
              context,
              Icons.mark_email_unread_outlined,
              'Notification & email templates',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationTemplatesScreen()),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(label: 'Save configuration', onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Widget _sliderRow(String label, double value, double min, double max, String display, ValueChanged<double> onChanged) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: textTheme.titleSmall),
              Text(display, style: textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(activeTrackColor: AppColors.primary, thumbColor: AppColors.primary),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _linkRow(BuildContext context, IconData icon, String label, {VoidCallback? onTap}) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: textTheme.bodyLarge)),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip();

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.add_rounded, size: 16),
      label: const Text('Add'),
    );
  }
}
