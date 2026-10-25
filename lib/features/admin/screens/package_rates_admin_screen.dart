import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/guarded_write.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/async_body.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import 'package_city_editor_screen.dart';

/// Staff keep the outstation rate charts customers see under Popular
/// packages: pick a city to change its charts, add a city, or reword the
/// note shown under every chart.
class PackageRatesAdminScreen extends ConsumerWidget {
  const PackageRatesAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final cities = ref.watch(packagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Package rates')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => PackageCityEditorScreen(
                  nextOrder: cities.items.length,
                  existingCities: [for (final c in cities.items) c.city])),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add a city'),
      ),
      body: SafeArea(
        child: AsyncBody<List<PackageLocation>>(
          value: cities,
          builder: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
            children: [
              Text(
                  'Customers see these under Popular packages. Changes show up straight away.',
                  style: textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              const _NoteCard(),
              const SizedBox(height: AppSpacing.xl),
              const SectionLabel('Cities'),
              if (list.isEmpty)
                Text('No rate charts yet. Add a city to start.',
                    style: textTheme.bodyMedium),
              for (final city in list) ...[
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PackageCityEditorScreen(
                        location: city,
                        nextOrder: city.order,
                        existingCities: [
                          for (final c in list)
                            if (c != city) c.city
                        ],
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(city.city, style: textTheme.titleSmall),
                            Text(
                              '${city.packages.length} ${city.packages.length == 1 ? 'chart' : 'charts'} · '
                              '${city.packages.fold<int>(0, (n, p) => n + p.trips.length)} destinations'
                              '${city.packages.any((p) => p.sampleRates) ? ' · sample rates' : ''}',
                              style: textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textTertiary),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The line customers read under every rate chart.
class _NoteCard extends ConsumerStatefulWidget {
  const _NoteCard();

  @override
  ConsumerState<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends ConsumerState<_NoteCard> {
  TextEditingController? _controller;
  String _saved = '';
  bool _saving = false;

  Future<void> _save(AppConfig config) async {
    setState(() => _saving = true);
    final text = _controller!.text.trim();
    final ok = await guardedWrite(
      context,
      () => ref
          .read(configRepositoryProvider)
          .save(config.copyWith(packageNote: text)),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _saved = text;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(appConfigProvider);
    if (!loaded.hasValue) return const SizedBox.shrink();
    final config = loaded.config;
    // Filled once from what is stored, so a later save elsewhere does not
    // overwrite what is being typed.
    if (_controller == null) {
      _saved = config.packageNote;
      _controller = TextEditingController(text: _saved);
    }
    final changed = _controller!.text.trim() != _saved;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Note under every chart',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            maxLines: 3,
            maxLength: 300,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                hintText:
                    'e.g. Rates exclude toll, parking and entry charges.'),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: _saving ? 'Saving…' : 'Save note',
            onPressed: changed && !_saving ? () => _save(config) : null,
          ),
        ],
      ),
    );
  }
}
