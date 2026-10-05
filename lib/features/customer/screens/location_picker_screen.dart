import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';

/// SRCH-02: locations are picked from an Admin-maintained city/area list
/// (no map services), with recent and saved locations offered first, plus
/// a free-text landmark captured separately on the search form.
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, required this.title});

  final String title;

  @override
  ConsumerState<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<LocationEntry> _filtered(List<LocationEntry> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((l) => l.label.toLowerCase().contains(q)).toList();
  }

  void _select(LocationEntry location) {
    Navigator.of(context).pop(location);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locations = ref.watch(locationsProvider).items;
    final recent = ref.watch(recentLocationsProvider).items;
    final filtered = _filtered(locations);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Search city or area',
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: ListView(
                  children: [
                    if (_query.isEmpty) ...[
                      const SectionLabel('Recent'),
                      for (final loc in recent) _row(loc, Icons.history_rounded),
                      const SizedBox(height: AppSpacing.lg),
                      const SectionLabel('Saved'),
                      for (final loc in locations.where((l) => l.saved))
                        _row(loc, Icons.bookmark_rounded),
                      const SizedBox(height: AppSpacing.lg),
                      const SectionLabel('All cities & areas'),
                    ],
                    for (final loc in filtered) _row(loc, Icons.place_outlined),
                    if (_query.isNotEmpty && filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxl),
                        child: Center(
                          child: Text('No matching location', style: textTheme.bodyMedium),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(LocationEntry loc, IconData icon) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _select(loc),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.area, style: textTheme.bodyLarge),
                  Text(loc.city, style: textTheme.labelMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
