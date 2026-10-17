import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/guarded_write.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/date_time_field.dart';
import '../../../data/ids.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/photo_repository.dart';
import '../photos/bus_photo_editor.dart';

/// BUS-01: vendor selection is mandatory before anything else on this
/// form — a bus cannot exist without a vendor. The driver and the weekly
/// charter windows are set here too; the windows are what customer search
/// filters on.
class BusFormScreen extends ConsumerStatefulWidget {
  const BusFormScreen({super.key, this.bus});

  final BusRecord? bus;

  @override
  ConsumerState<BusFormScreen> createState() => _BusFormScreenState();
}

const _unassigned = 'Unassigned';
const _addNewDriver = '__add_new_driver__';

class _BusFormScreenState extends ConsumerState<BusFormScreen> {
  static const _capacities = [17, 20, 27, 30, 35, 40];
  static const _seatTypes = ['Pushback', 'Highback', 'Basic'];
  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late final _regNumber =
      TextEditingController(text: widget.bus?.regNumber ?? '');
  late final _baseCity =
      TextEditingController(text: widget.bus?.baseCity ?? '');
  late final _gpsLink = TextEditingController(text: widget.bus?.gpsLink ?? '');
  final _newDriverName = TextEditingController();
  final _newDriverPhone = TextEditingController();
  final _newDriverLicence = TextEditingController();

  late String? _vendorId = widget.bus?.vendorId;
  late int _capacity = widget.bus?.capacity ?? 20;
  late String _seatType = widget.bus?.seatType.split(' ').first ?? 'Pushback';
  late bool _ac = widget.bus?.ac ?? true;
  late bool _active = widget.bus?.active ?? true;
  late String _driver = widget.bus?.driverId ?? _unassigned;
  late final List<DayAvailability> _week = List<DayAvailability>.from(
    widget.bus?.weeklyAvailability ??
        List.filled(7, const DayAvailability(available: true)),
  );

  // The bus has its id from the moment the form opens, so photos can be
  // uploaded under it before the first save.
  late final String _busId = widget.bus?.id ?? newId('bus');
  late List<BusPhoto> _photos =
      List<BusPhoto>.of(widget.bus?.photos ?? const []);
  bool _photosBusy = false;

  /// Files uploaded in this session and not yet saved on the bus. If the form
  /// is abandoned, or one of them is removed, they are deleted again.
  final Set<BusPhoto> _unsaved = {};
  bool _saved = false;
  // Looked up when the form opens: a provider cannot be read while the form is closing.
  late final PhotoRepository _photoRepo;

  @override
  void initState() {
    super.initState();
    _photoRepo = ref.read(photoRepositoryProvider);
  }

  bool get _isEdit => widget.bus != null;
  bool get _addingDriver => _driver == _addNewDriver;

  void _photoRemoved(BusPhoto photo) {
    // Never saved: nothing refers to it, so the files can go now. A photo that
    // is already on the bus is removed by the server once the save lands.
    if (_unsaved.remove(photo)) {
      _photoRepo.discard(_busId, photo).catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    _regNumber.dispose();
    _baseCity.dispose();
    _gpsLink.dispose();
    _newDriverName.dispose();
    _newDriverPhone.dispose();
    _newDriverLicence.dispose();
    if (!_saved) {
      for (final photo in _unsaved) {
        _photoRepo.discard(_busId, photo).catchError((Object _) {});
      }
    }
    super.dispose();
  }

  List<DriverRecord> get _vendorDrivers => ref
      .watch(driversProvider)
      .items
      .where((d) => d.vendorId == _vendorId)
      .toList();

  bool get _canSave {
    if (_photosBusy) return false;
    if (_vendorId == null || _regNumber.text.trim().isEmpty) return false;
    if (_addingDriver) {
      return _newDriverName.text.trim().isNotEmpty &&
          _newDriverPhone.text.trim().isNotEmpty;
    }
    return true;
  }

  void _applyMondayToAllDays() {
    setState(() {
      for (var i = 1; i < 7; i++) {
        _week[i] = _week[0];
      }
    });
  }

  Future<void> _save() async {
    final vendor =
        ref.read(vendorsProvider).items.firstWhere((v) => v.id == _vendorId);
    final drivers = ref.read(driversProvider).items;

    String? driverId;
    var driverName = _unassigned;

    DriverRecord? newDriver;
    if (_addingDriver) {
      final licence = _newDriverLicence.text.trim();
      final driver = newDriver = DriverRecord(
        id: newId('drv'),
        name: _newDriverName.text.trim(),
        phone: _newDriverPhone.text.trim(),
        vendorId: vendor.id,
        vendorName: vendor.name,
        licenceNumber: licence.isEmpty ? null : licence,
      );
      driverId = driver.id;
      driverName = driver.name;
    } else if (_driver != _unassigned) {
      final driver = drivers.firstWhere((d) => d.id == _driver);
      driverId = driver.id;
      driverName = driver.name;
    }

    final gps = _gpsLink.text.trim();
    final record = BusRecord(
      id: _busId,
      regNumber: _regNumber.text.trim(),
      vendorId: vendor.id,
      vendorName: vendor.name,
      capacity: _capacity,
      seatType: '$_seatType seats',
      ac: _ac,
      baseCity: _baseCity.text.trim(),
      driverId: driverId,
      driverName: driverName,
      active: _active,
      gpsLink: gps.isEmpty ? null : gps,
      weeklyAvailability: _week,
      amenities: widget.bus?.amenities ?? [if (_ac) 'AC', '$_seatType seats'],
      photos: _photos,
    );
    // A new driver is saved first so the bus never points at one that is not there.
    final saved = await guardedWrite(context, () async {
      if (newDriver != null) {
        await ref.read(driverRepositoryProvider).upsert(newDriver);
      }
      await ref.read(busRepositoryProvider).upsert(record);
    });

    if (saved) _saved = true;
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit bus' : 'Add bus')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          children: [
            const SectionLabel('Vendor'),
            _dropdown<String>(
              value: _vendorId,
              hint: 'Select vendor (required)',
              items: ref
                  .watch(vendorsProvider)
                  .items
                  .where((v) => v.active)
                  .map(
                      (v) => DropdownMenuItem(value: v.id, child: Text(v.name)))
                  .toList(),
              onChanged: (v) => setState(() {
                _vendorId = v;
                _driver = _unassigned;
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(
              label: 'Registration number',
              controller: _regNumber,
              hint: 'e.g. MH-04-BT-7781',
            ),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(label: 'Base city', controller: _baseCity),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Capacity'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _capacities
                  .map((c) => _chip('$c', c == _capacity,
                      () => setState(() => _capacity = c)))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Seat type'),
            Wrap(
              spacing: AppSpacing.sm,
              children: _seatTypes
                  .map((s) => _chip(
                      s, s == _seatType, () => setState(() => _seatType = s)))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                      child:
                          Text('Air conditioned', style: textTheme.titleSmall)),
                  Switch(
                      value: _ac,
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) => setState(() => _ac = v)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Driver'),
            _dropdown<String>(
              value: _driver,
              hint: 'Select driver',
              items: [
                const DropdownMenuItem(
                    value: _unassigned, child: Text(_unassigned)),
                for (final d in _vendorDrivers)
                  DropdownMenuItem(
                      value: d.id, child: Text('${d.name} · ${d.phone}')),
                const DropdownMenuItem(
                  value: _addNewDriver,
                  child: Text('+ Add new driver',
                      style: TextStyle(color: AppColors.primary)),
                ),
              ],
              onChanged: _vendorId == null
                  ? null
                  : (v) => setState(() => _driver = v ?? _unassigned),
            ),
            if (_vendorId == null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Pick a vendor first — drivers are listed per vendor.',
                  style: textTheme.labelMedium),
            ],
            if (_addingDriver) ...[
              const SizedBox(height: AppSpacing.lg),
              LabeledField(
                label: 'Driver name',
                controller: _newDriverName,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.lg),
              LabeledField(
                label: 'Mobile number',
                controller: _newDriverPhone,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.lg),
              LabeledField(
                  label: 'Driving licence (optional)',
                  controller: _newDriverLicence),
            ],
            const SizedBox(height: AppSpacing.xl),
            SectionLabel(
              'Availability',
              trailing: InkWell(
                onTap: _applyMondayToAllDays,
                borderRadius: AppRadius.tagRadius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs, vertical: 2),
                  child: Text(
                    'Apply to all days',
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium
                        ?.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            Text(
              'Customers can only charter this bus inside these hours.',
              style: textTheme.labelMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < 7; i++) _dayRow(i),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(
                label: 'GPS link', controller: _gpsLink, hint: 'https://...'),
            const SizedBox(height: AppSpacing.lg),
            const SectionLabel('Photographs (up to 4)'),
            BusPhotoEditor(
              busId: _busId,
              photos: _photos,
              onChanged: (photos) => setState(() => _photos = photos),
              onBusyChanged: (busy) {
                if (_photosBusy != busy) setState(() => _photosBusy = busy);
              },
              onUploaded: _unsaved.add,
              onDiscarded: _photoRemoved,
            ),
            if (_isEdit) ...[
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active', style: textTheme.titleSmall),
                          Text(
                              'Deactivating removes this bus from search immediately.',
                              style: textTheme.labelMedium),
                        ],
                      ),
                    ),
                    Switch(
                        value: _active,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() => _active = v)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: _photosBusy
                  ? 'Uploading photos…'
                  : (_isEdit ? 'Save changes' : 'Add bus'),
              onPressed: _canSave ? _save : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayRow(int index) {
    final textTheme = Theme.of(context).textTheme;
    final day = _week[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                    width: 96,
                    child: Text(_dayNames[index], style: textTheme.titleSmall)),
                Expanded(
                  child: day.available
                      ? const SizedBox.shrink()
                      : Text('Unavailable', style: textTheme.labelMedium),
                ),
                Switch(
                  value: day.available,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) =>
                      setState(() => _week[index] = day.copyWith(available: v)),
                ),
              ],
            ),
            if (day.available) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TimeField(
                      label: 'From',
                      value: day.start,
                      onChanged: (t) =>
                          setState(() => _week[index] = day.copyWith(start: t)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TimeField(
                      label: 'To',
                      value: day.end,
                      onChanged: (t) =>
                          setState(() => _week[index] = day.copyWith(end: t)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.controlRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          // The list may still be loading, in which case the saved choice is
          // not among the items yet and must not be passed as the value.
          value: items.any((item) => item.value == value) ? value : null,
          isExpanded: true,
          hint: Text(hint),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    final textTheme = Theme.of(context).textTheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      labelStyle: textTheme.labelMedium?.copyWith(
          color: selected ? AppColors.onPrimary : AppColors.textPrimary),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      showCheckmark: false,
    );
  }
}
