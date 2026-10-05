import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/date_time_field.dart';
import '../../../data/availability.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../widgets/customer_bottom_nav.dart';
import 'location_picker_screen.dart';
import 'my_bookings_screen.dart';
import 'notifications_screen.dart';
import 'popular_packages_screen.dart';
import 'profile_screen.dart';
import 'results_screen.dart';

class HomeSearchScreen extends ConsumerStatefulWidget {
  const HomeSearchScreen({super.key});

  @override
  ConsumerState<HomeSearchScreen> createState() => _HomeSearchScreenState();
}

class _HomeSearchScreenState extends ConsumerState<HomeSearchScreen> {
  int _tripTypeIndex = 0; // 0 = single trip, 1 = round trip
  int _scopeIndex = 0; // 0 = local, 1 = outstation
  int? _capacityIndex = 1;
  final _landmark = TextEditingController();

  late DateTime _pickupDate = _today;
  TimeOfDay _pickupTime = const TimeOfDay(hour: 6, minute: 0);
  late DateTime _dropDate = _today;
  TimeOfDay _dropTime = const TimeOfDay(hour: 18, minute: 0);
  late DateTime _returnDate = _today.add(const Duration(days: 1));

  DateTime get _today => dateOnly(ref.read(clockProvider)());
  TimeOfDay _returnTime = const TimeOfDay(hour: 17, minute: 0);

  LocationEntry _pickupLocation = const LocationEntry(city: 'Thane', area: 'Thane West');
  LocationEntry _dropLocation = const LocationEntry(city: 'Mahabaleshwar', area: 'Main Market');

  static const _capacities = [17, 20, 35, 40];

  bool get _isRoundTrip => _tripTypeIndex == 1;

  @override
  void dispose() {
    _landmark.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    switch (index) {
      case 1:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
      case 2:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      case 3:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    }
  }

  Future<void> _pickLocation({required bool pickup}) async {
    final result = await Navigator.of(context).push<LocationEntry>(
      MaterialPageRoute(builder: (_) => LocationPickerScreen(title: pickup ? 'Pickup location' : 'Drop location')),
    );
    if (result == null) return;
    setState(() {
      if (pickup) {
        _pickupLocation = result;
      } else {
        _dropLocation = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _hero(textTheme),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _segmented(['Single trip', 'Round trip'], _tripTypeIndex, (i) => setState(() => _tripTypeIndex = i)),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionLabel('Trip type'),
                  _choiceChips(['Local', 'Outstation'], _scopeIndex, (i) => setState(() => _scopeIndex = i)),
                  if (_scopeIndex == 1) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PopularPackagesScreen()),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_offer_outlined, size: 19, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Popular outstation packages', style: textTheme.titleSmall),
                                Text(
                                  'Fixed return rates from Mumbai, Navi Mumbai and Thane',
                                  style: textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  LabeledField(
                    key: ValueKey('pickup-${_pickupLocation.label}'),
                    label: 'Pickup — city / area',
                    initialValue: _pickupLocation.label,
                    readOnly: true,
                    suffixIcon: Icons.place_outlined,
                    onTap: () => _pickLocation(pickup: true),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LabeledField(
                    label: 'Pickup landmark (optional)',
                    controller: _landmark,
                    hint: 'e.g. near Viviana Mall',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DateField(
                          label: 'Date',
                          value: _pickupDate,
                          onChanged: (d) => setState(() => _pickupDate = d),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TimeField(
                          label: 'Time',
                          value: _pickupTime,
                          onChanged: (t) => setState(() => _pickupTime = t),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LabeledField(
                    key: ValueKey('drop-${_dropLocation.label}'),
                    label: 'Drop — city / area',
                    initialValue: _dropLocation.label,
                    readOnly: true,
                    suffixIcon: Icons.place_outlined,
                    onTap: () => _pickLocation(pickup: false),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DateField(
                          label: 'Drop date',
                          value: _dropDate,
                          firstDate: _pickupDate,
                          onChanged: (d) => setState(() => _dropDate = d),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TimeField(
                          label: 'Drop time',
                          value: _dropTime,
                          onChanged: (t) => setState(() => _dropTime = t),
                        ),
                      ),
                    ],
                  ),
                  if (_isRoundTrip) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: AppRadius.controlRadius,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'The bus stays with you for the whole round trip, including any days in between.',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DateField(
                            label: 'Return date',
                            value: _returnDate,
                            firstDate: _dropDate,
                            onChanged: (d) => setState(() => _returnDate = d),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TimeField(
                            label: 'Return time',
                            value: _returnTime,
                            onChanged: (t) => setState(() => _returnTime = t),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  const SectionLabel('Preferred capacity (optional)'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: List.generate(_capacities.length, (i) {
                      final selected = _capacityIndex == i;
                      return _CapacityChip(
                        label: '${_capacities[i]}',
                        selected: selected,
                        onTap: () => setState(() => _capacityIndex = i),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  PrimaryButton(
                    label: 'Search buses',
                    icon: Icons.search_rounded,
                    onPressed: () {
                      final summary =
                          '${_pickupLocation.area} → ${_dropLocation.area} · ${AppDateFormat.dayMonthYear(_pickupDate)}, ${AppDateFormat.hourMinute(_pickupTime)}'
                          '${_isRoundTrip ? ' · returns ${AppDateFormat.dayMonthYear(_returnDate)}' : ''}';
                      final criteria = SearchCriteria(
                        pickup: _pickupLocation,
                        drop: _dropLocation,
                        pickupDate: _pickupDate,
                        pickupTime: _pickupTime,
                        dropDate: _dropDate,
                        dropTime: _dropTime,
                        isRoundTrip: _isRoundTrip,
                        returnDate: _returnDate,
                        returnTime: _returnTime,
                        capacity: _capacityIndex == null ? null : _capacities[_capacityIndex!],
                        pickupLandmark: _landmark.text.trim(),
                        summary: summary,
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ResultsScreen(criteria: criteria)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomerBottomNav(currentIndex: 0, onTap: _onNavTap),
    );
  }

  Widget _hero(TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxxl),
      decoration: const BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.hero),
          bottomRight: Radius.circular(AppRadius.hero),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: AppRadius.controlRadius,
                ),
                child: const Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'CharterBooking',
                style: textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Find a bus',
            style: textTheme.displaySmall?.copyWith(color: Colors.white, fontSize: 26),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'One vehicle, confirmed by our team — no seats to pick.',
            style: textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _segmented(List<String> labels, int selected, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.controlRadius),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.background : Colors.transparent,
                  borderRadius: AppRadius.controlRadius,
                  border: isSelected ? Border.all(color: AppColors.border) : null,
                  boxShadow: isSelected
                      ? const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _choiceChips(List<String> labels, int selected, ValueChanged<int> onChanged) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: List.generate(labels.length, (i) {
        final isSelected = i == selected;
        return Padding(
          padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : AppSpacing.sm),
          child: ChoiceChip(
            label: Text(labels[i]),
            selected: isSelected,
            onSelected: (_) => onChanged(i),
            selectedColor: AppColors.primary,
            labelStyle: textTheme.labelMedium?.copyWith(
              color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
            ),
            side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
            showCheckmark: false,
          ),
        );
      }),
    );
  }
}

class _CapacityChip extends StatelessWidget {
  const _CapacityChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.primary : null,
          color: selected ? null : AppColors.surface,
          borderRadius: AppRadius.controlRadius,
          border: Border.all(color: selected ? Colors.transparent : AppColors.border),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
