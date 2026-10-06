import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/guarded_write.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../data/ids.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';

/// VEN-01/VEN-02: register or edit a vendor. A vendor with active buses
/// cannot be deleted — only deactivated.
class VendorFormScreen extends ConsumerStatefulWidget {
  const VendorFormScreen({super.key, this.vendor});

  final Vendor? vendor;

  @override
  ConsumerState<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends ConsumerState<VendorFormScreen> {
  late final _name = TextEditingController(text: widget.vendor?.name ?? '');
  late final _contact = TextEditingController(text: widget.vendor?.contactPerson ?? '');
  late final _phone = TextEditingController(text: widget.vendor?.phone ?? '');
  late final _email = TextEditingController(text: widget.vendor?.email ?? '');
  late final _address = TextEditingController(text: widget.vendor?.address ?? '');
  late final _pan = TextEditingController(text: widget.vendor?.pan ?? '');
  late final _gst = TextEditingController(text: widget.vendor?.gst ?? '');
  late bool _active = widget.vendor?.active ?? true;

  bool get _isEdit => widget.vendor != null;

  bool get _canSave =>
      _name.text.trim().isNotEmpty && _contact.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty;

  @override
  void dispose() {
    for (final c in [_name, _contact, _phone, _email, _address, _pan, _gst]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _orNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final vendor = Vendor(
      id: widget.vendor?.id ?? newId('ven'),
      name: _name.text.trim(),
      contactPerson: _contact.text.trim(),
      phone: _phone.text.trim(),
      active: _active,
      email: _orNull(_email),
      address: _orNull(_address),
      pan: _orNull(_pan),
      gst: _orNull(_gst),
    );
    final saved = await guardedWrite(context, () => ref.read(vendorRepositoryProvider).upsert(vendor));
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit vendor' : 'Add vendor')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          children: [
            LabeledField(
              label: 'Trading name',
              controller: _name,
              hint: 'e.g. Neeta Travels',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(label: 'Contact person', controller: _contact, onChanged: (_) => setState(() {})),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(
              label: 'Phone',
              controller: _phone,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(
              label: 'Email',
              controller: _email,
              hint: 'accounts@vendor.example',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(label: 'Address', controller: _address, hint: 'Registered address'),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: LabeledField(label: 'PAN (optional)', controller: _pan)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: LabeledField(label: 'GST (optional)', controller: _gst)),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_isEdit)
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active', style: textTheme.titleSmall),
                          Text(
                            'Deactivating removes their buses from search but leaves existing bookings untouched.',
                            style: textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                    Switch(value: _active, activeThumbColor: AppColors.primary, onChanged: (v) => setState(() => _active = v)),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: _isEdit ? 'Save changes' : 'Add vendor',
              onPressed: _canSave ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}
