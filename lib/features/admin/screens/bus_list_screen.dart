import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../../shared/bus_photo.dart';
import '../widgets/admin_bottom_nav.dart';
import 'booking_queue_screen.dart';
import 'bus_calendar_screen.dart';
import 'bus_form_screen.dart';
import 'reports_screen.dart';

/// BUS-01..07: bus master list. Reachable from the dashboard and from the
/// admin bottom nav's "Masters" tab.
class BusListScreen extends ConsumerStatefulWidget {
  const BusListScreen({super.key});

  @override
  ConsumerState<BusListScreen> createState() => _BusListScreenState();
}

class _BusListScreenState extends ConsumerState<BusListScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const BookingQueueScreen()));
      case 1:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const BusCalendarScreen()));
      case 3:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ReportsScreen()));
    }
  }

  void _openForm([BusRecord? bus]) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => BusFormScreen(bus: bus)));
  }

  /// Matches the reg number first, but every other detail on the row too,
  /// so "Neeta", "Pushback", "Thane" or "35" all narrow the list.
  List<BusRecord> _filtered(List<BusRecord> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((b) {
      final haystack = [
        b.regNumber,
        b.vendorName,
        b.seatType,
        b.baseCity,
        b.driverName,
        '${b.capacity} seater',
        if (b.ac) 'AC',
        b.active ? 'active' : 'inactive',
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final buses = _filtered(ref.watch(busesProvider).items);
    return Scaffold(
      appBar: AppBar(title: const Text('Buses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add bus'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
              child: TextField(
                controller: _controller,
                onChanged: (v) => setState(() => _query = v),
                style: textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Search bus number, vendor, city…',
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: AppColors.textTertiary),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: AppColors.textTertiary),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: buses.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxl),
                      child: Text('No bus matches "$_query"',
                          style: textTheme.bodyMedium,
                          textAlign: TextAlign.center),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl,
                          AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
                      itemCount: buses.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) {
                        final bus = buses[i];
                        return AppCard(
                          onTap: () => _openForm(bus),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: AppRadius.controlRadius,
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: BusPhotoView(
                                      url: bus.cover?.thumbUrl,
                                      decodeWidth: 56),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                            child: Text(bus.regNumber,
                                                style: textTheme.titleSmall)),
                                        StatusBadge(
                                          label: bus.active
                                              ? 'Active'
                                              : 'Inactive',
                                          tone: bus.active
                                              ? StatusTone.success
                                              : StatusTone.neutral,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                        '${bus.vendorName} · ${bus.capacity} seater · ${bus.seatType}',
                                        style: textTheme.bodyMedium),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (bus.ac) ...[
                                          const StatusBadge(label: 'AC'),
                                          const SizedBox(width: AppSpacing.sm)
                                        ],
                                        const Icon(Icons.person_outline_rounded,
                                            size: 14,
                                            color: AppColors.textTertiary),
                                        const SizedBox(width: 2),
                                        Text(bus.driverName,
                                            style: textTheme.labelMedium),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AdminBottomNav(currentIndex: 2, onTap: _onNavTap),
    );
  }
}
