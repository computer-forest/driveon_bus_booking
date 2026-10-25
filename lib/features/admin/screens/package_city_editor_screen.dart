import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/guarded_write.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';

/// The highest rate a chart accepts, in rupees; matches what the server
/// accepts for any amount of money.
const int maxPackageRate = 10000000;

class _TripDraft {
  _TripDraft({String destination = '', int? oneDay, int? twoDay})
      : destination = TextEditingController(text: destination),
        oneDay = TextEditingController(text: oneDay?.toString() ?? ''),
        twoDay = TextEditingController(text: twoDay?.toString() ?? '');

  final TextEditingController destination;
  final TextEditingController oneDay;
  final TextEditingController twoDay;

  int? get oneDayValue => int.tryParse(oneDay.text.trim());
  int? get twoDayValue => int.tryParse(twoDay.text.trim());

  void dispose() {
    destination.dispose();
    oneDay.dispose();
    twoDay.dispose();
  }
}

class _ChartDraft {
  _ChartDraft(
      {String seater = '', this.sample = false, List<_TripDraft>? trips})
      : seater = TextEditingController(text: seater),
        trips = trips ?? [_TripDraft()];

  final TextEditingController seater;
  bool sample;
  final List<_TripDraft> trips;

  void dispose() {
    seater.dispose();
    for (final t in trips) {
      t.dispose();
    }
  }
}

/// One city's rate charts: a chart per seater class, a row per destination
/// with its 1-day and 2-day rate. Nothing is saved until every row is valid.
class PackageCityEditorScreen extends ConsumerStatefulWidget {
  const PackageCityEditorScreen(
      {super.key,
      this.location,
      required this.nextOrder,
      this.existingCities = const []});

  /// Null when adding a new city.
  final PackageLocation? location;

  /// Where the city goes in the list: its own place when editing, the end
  /// when new.
  final int nextOrder;

  /// The other cities, so a name is not used twice.
  final List<String> existingCities;

  @override
  ConsumerState<PackageCityEditorScreen> createState() =>
      _PackageCityEditorScreenState();
}

class _PackageCityEditorScreenState
    extends ConsumerState<PackageCityEditorScreen> {
  late final _city = TextEditingController(text: widget.location?.city ?? '');
  late final List<_ChartDraft> _charts = [
    for (final p in widget.location?.packages ?? const <SeaterPackage>[])
      _ChartDraft(
        seater: p.seater,
        sample: p.sampleRates,
        trips: [
          for (final t in p.trips)
            _TripDraft(
                destination: t.destination,
                oneDay: t.oneDayRate,
                twoDay: t.twoDayRate)
        ],
      ),
  ];
  bool _saving = false;
  bool _showErrors = false;

  bool get _isNew => widget.location == null;

  @override
  void initState() {
    super.initState();
    if (_charts.isEmpty) _charts.add(_ChartDraft());
  }

  @override
  void dispose() {
    _city.dispose();
    for (final c in _charts) {
      c.dispose();
    }
    super.dispose();
  }

  /// The first thing wrong, in words, or null when the charts can be saved.
  String? get _problem {
    final city = _city.text.trim();
    if (city.isEmpty) {
      return 'Enter the city name.';
    }
    if (widget.existingCities
        .any((c) => c.trim().toLowerCase() == city.toLowerCase())) {
      return '$city already has rate charts. Open it from the list instead.';
    }
    if (_isNew && PackageLocation.idFor(city).isEmpty) {
      return 'Use letters or numbers in the city name.';
    }
    final seen = <String>{};
    for (final chart in _charts) {
      final seater = chart.seater.text.trim();
      if (seater.isEmpty) {
        return 'Give each chart a name, such as "17–20 seater Tempo traveller".';
      }
      if (!seen.add(seater.toLowerCase())) {
        return 'Two charts are both called "$seater".';
      }
      if (chart.trips.isEmpty) {
        return '"$seater" needs at least one destination.';
      }
      final places = <String>{};
      for (final trip in chart.trips) {
        final place = trip.destination.text.trim();
        if (place.isEmpty) {
          return 'Every row in "$seater" needs a destination.';
        }
        if (!places.add(place.toLowerCase())) {
          return '"$place" is listed twice in "$seater".';
        }
        for (final rate in [trip.oneDayValue, trip.twoDayValue]) {
          if (rate == null || rate < 1) {
            return 'Enter the 1-day and 2-day rate for $place, in rupees.';
          }
          if (rate > maxPackageRate) {
            return 'The rate for $place is too high.';
          }
        }
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_problem != null) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    final location = PackageLocation(
      id: widget.location?.id,
      order: widget.nextOrder,
      city: _city.text.trim(),
      packages: [
        for (final c in _charts)
          SeaterPackage(
            seater: c.seater.text.trim(),
            sampleRates: c.sample,
            trips: [
              for (final t in c.trips)
                PackageTrip(
                    destination: t.destination.text.trim(),
                    oneDayRate: t.oneDayValue!,
                    twoDayRate: t.twoDayValue!),
            ],
          ),
      ],
    );
    final saved = await guardedWrite(
        context, () => ref.read(packageRepositoryProvider).save(location));
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final problem = _showErrors ? _problem : null;
    return Scaffold(
      appBar:
          AppBar(title: Text(_isNew ? 'Add a city' : widget.location!.city)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
          children: [
            LabeledField(
                label: 'City',
                controller: _city,
                hint: 'e.g. Pune',
                onChanged: (_) => setState(() {})),
            const SizedBox(height: AppSpacing.xl),
            for (var i = 0; i < _charts.length; i++) ...[
              _chartCard(context, i),
              const SizedBox(height: AppSpacing.lg),
            ],
            SecondaryButton(
              label: 'Add another chart',
              icon: Icons.add_rounded,
              onPressed: () => setState(() => _charts.add(_ChartDraft())),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (problem != null) ...[
              Text(problem,
                  style:
                      textTheme.bodyMedium?.copyWith(color: AppColors.urgent)),
              const SizedBox(height: AppSpacing.md),
            ],
            PrimaryButton(
                label: _saving ? 'Saving…' : 'Save rates',
                onPressed: _saving ? null : _save),
          ],
        ),
      ),
    );
  }

  Widget _chartCard(BuildContext context, int index) {
    final textTheme = Theme.of(context).textTheme;
    final chart = _charts[index];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Chart name',
                  controller: chart.seater,
                  hint: 'e.g. 17–20 seater Tempo traveller',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_charts.length > 1)
                IconButton(
                  tooltip: 'Remove chart',
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.textTertiary),
                  onPressed: () =>
                      setState(() => _charts.removeAt(index).dispose()),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                  child: Text('Rates are only samples',
                      style: textTheme.bodyMedium)),
              Switch(
                value: chart.sample,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => chart.sample = v),
              ),
            ],
          ),
          if (chart.sample)
            Text(
                'Customers are told these rates are indicative until you switch this off.',
                style: textTheme.labelMedium),
          const SizedBox(height: AppSpacing.md),
          for (var t = 0; t < chart.trips.length; t++) ...[
            _tripRow(context, chart, t),
            const SizedBox(height: AppSpacing.md),
          ],
          SecondaryButton(
            label: 'Add a destination',
            icon: Icons.add_rounded,
            onPressed: () => setState(() => chart.trips.add(_TripDraft())),
          ),
        ],
      ),
    );
  }

  Widget _tripRow(BuildContext context, _ChartDraft chart, int t) {
    final trip = chart.trips[t];
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 5,
          child: LabeledField(
              label: 'Destination',
              controller: trip.destination,
              hint: 'e.g. Karjat',
              onChanged: (_) => setState(() {})),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 3,
          child: LabeledField(
            label: '1 day ₹',
            controller: trip.oneDay,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 3,
          child: LabeledField(
            label: '2 days ₹',
            controller: trip.twoDay,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (chart.trips.length > 1)
          IconButton(
            tooltip: 'Remove destination',
            icon:
                const Icon(Icons.close_rounded, color: AppColors.textTertiary),
            onPressed: () => setState(() => chart.trips.removeAt(t).dispose()),
          ),
      ],
    );
  }
}
