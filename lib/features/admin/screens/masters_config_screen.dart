import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/guarded_write.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/async_body.dart';
import '../../../data/ids.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import 'notification_templates_screen.dart';

/// ADM-11: cities/areas, capacities, hold duration, buffer defaults,
/// support/WhatsApp numbers, Terms & Privacy content, template access.
class MastersConfigScreen extends ConsumerWidget {
  const MastersConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Masters & configuration')),
      body: SafeArea(
        child: AsyncBody<AppConfig>(
          value: ref.watch(appConfigProvider),
          builder: (config) => _ConfigForm(initial: config),
        ),
      ),
    );
  }
}

class _ConfigForm extends ConsumerStatefulWidget {
  const _ConfigForm({required this.initial});

  final AppConfig initial;

  @override
  ConsumerState<_ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends ConsumerState<_ConfigForm> {
  late double _holdMinutes = widget.initial.holdMinutes.toDouble();
  late double _preBuffer = widget.initial.preBufferMinutes.toDouble();
  late double _postBuffer = widget.initial.postBufferMinutes.toDouble();
  late final _supportPhone =
      TextEditingController(text: widget.initial.supportPhone);
  late final _whatsapp =
      TextEditingController(text: widget.initial.whatsappNumber);
  late final _advancePercent =
      TextEditingController(text: '${widget.initial.defaultAdvancePercent}');

  @override
  void dispose() {
    _supportPhone.dispose();
    _whatsapp.dispose();
    _advancePercent.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final percent = int.tryParse(_advancePercent.text.trim());
    final saved = await guardedWrite(
      context,
      () => ref.read(configRepositoryProvider).save(
            widget.initial.copyWith(
              holdMinutes: _holdMinutes.round(),
              preBufferMinutes: _preBuffer.round(),
              postBufferMinutes: _postBuffer.round(),
              defaultAdvancePercent: percent?.clamp(0, 100),
              supportPhone: _supportPhone.text.trim(),
              whatsappNumber: _whatsapp.text.trim(),
            ),
          ),
    );
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Configuration saved.')));
  }

  Future<void> _addLocation() async {
    final city = TextEditingController();
    final area = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a city or area'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: city,
                decoration: const InputDecoration(hintText: 'City')),
            const SizedBox(height: AppSpacing.md),
            TextField(
                controller: area,
                decoration: const InputDecoration(hintText: 'Area')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add')),
        ],
      ),
    );
    final cityName = city.text.trim();
    final areaName = area.text.trim();
    city.dispose();
    area.dispose();
    if (added != true || cityName.isEmpty || areaName.isEmpty) return;
    if (!mounted) return;
    await guardedWrite(
      context,
      () => ref.read(locationRepositoryProvider).add(
            LocationEntry(id: newId('loc'), city: cityName, area: areaName),
          ),
    );
  }

  Future<void> _removeCity(String city, List<LocationEntry> all) async {
    final repo = ref.read(locationRepositoryProvider);
    await guardedWrite(context, () async {
      for (final l in all.where((l) => l.city == city)) {
        await repo.remove(l.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locations = ref.watch(locationsProvider).items;
    final cities = {for (final l in locations) l.city};
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
      children: [
        const SectionLabel('Hold & buffer defaults'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sliderRow(
                  'Hold duration',
                  _holdMinutes,
                  10,
                  60,
                  '${_holdMinutes.round()} min',
                  (v) => setState(() => _holdMinutes = v)),
              const HairlineDivider(),
              _sliderRow(
                  'Pre-trip buffer',
                  _preBuffer,
                  0,
                  120,
                  '${_preBuffer.round()} min',
                  (v) => setState(() => _preBuffer = v)),
              const HairlineDivider(),
              _sliderRow(
                  'Post-trip buffer',
                  _postBuffer,
                  0,
                  120,
                  '${_postBuffer.round()} min',
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
        SectionLabel('Cities & areas',
            trailing: _AddChip(onPressed: _addLocation)),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: cities.map((city) {
            return Chip(
                label: Text(city),
                onDeleted: () => _removeCity(city, locations));
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionLabel('Capacity list'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: widget.initial.capacities
              .map((c) => Chip(label: Text('$c seater')))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionLabel('Support & advance'),
        LabeledField(
            label: 'Support phone number',
            controller: _supportPhone,
            keyboardType: TextInputType.phone),
        const SizedBox(height: AppSpacing.lg),
        LabeledField(
            label: 'WhatsApp number',
            controller: _whatsapp,
            keyboardType: TextInputType.phone),
        const SizedBox(height: AppSpacing.lg),
        LabeledField(
            label: 'Default advance %',
            controller: _advancePercent,
            keyboardType: TextInputType.number),
        const SizedBox(height: AppSpacing.xl),
        const SectionLabel('Content'),
        _linkRow(context, Icons.description_outlined, 'Terms & Conditions'),
        _linkRow(context, Icons.privacy_tip_outlined, 'Privacy Policy'),
        _linkRow(
          context,
          Icons.mark_email_unread_outlined,
          'Notification & email templates',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const NotificationTemplatesScreen()),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        PrimaryButton(label: 'Save configuration', onPressed: _save),
      ],
    );
  }

  Widget _sliderRow(String label, double value, double min, double max,
      String display, ValueChanged<double> onChanged) {
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
              Text(display,
                  style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                thumbColor: AppColors.primary),
            child:
                Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _linkRow(BuildContext context, IconData icon, String label,
      {VoidCallback? onTap}) {
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
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded, size: 16),
      label: const Text('Add'),
    );
  }
}
