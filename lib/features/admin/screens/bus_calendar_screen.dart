import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../data/availability.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/booking_card.dart';
import 'admin_booking_detail_screen.dart';
import 'booking_queue_screen.dart';
import 'bus_form_screen.dart';
import 'bus_list_screen.dart';
import 'reports_screen.dart';

/// One day at a time: fleet timelines for an at-a-glance read on who is
/// free, and a full trip list underneath so the admin never has to tap a
/// bar just to find out who booked it.
class BusCalendarScreen extends ConsumerStatefulWidget {
  const BusCalendarScreen({super.key});

  @override
  ConsumerState<BusCalendarScreen> createState() => _BusCalendarScreenState();
}

/// Visible span of the timeline. Charter windows sit inside working hours,
/// so showing a full 24h would squeeze every bar into the middle third.
const _rulerStart = 6.0;
const _rulerEnd = 23.0;
const _trackHeight = 36.0;

class _BusCalendarScreenState extends ConsumerState<BusCalendarScreen> {
  late DateTime _day = dateOnly(ref.read(clockProvider)());

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BookingQueueScreen()));
      case 2:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BusListScreen()));
      case 3:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ReportsScreen()));
    }
  }

  void _shift(int days) => setState(() => _day = _day.add(Duration(days: days)));

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _day = picked);
  }

  void _openBooking(Booking booking) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminBookingDetailScreen(booking: booking)));
  }

  List<Booking> _bookingsToday(List<Booking> all) {
    final dayStart = dateOnly(_day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return all.where((b) => b.start.isBefore(dayEnd) && dayStart.isBefore(b.end)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  bool _isFreeAllDay(BusRecord bus, List<Booking> bookings, List<BlackoutEntry> blackouts) {
    if (!availabilityFor(bus, _day).available) return false;
    if (blackoutOn(bus.id, _day, blackouts) != null) return false;
    return bookingsFor(bus.id, _day, bookings).isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final buses = ref.watch(busesProvider).items.where((b) => b.active).toList();
    final allBookings = ref.watch(bookingsProvider).items;
    final blackouts = ref.watch(blackoutsProvider).items;
    final trips = _bookingsToday(allBookings);
    final freeCount = buses.where((b) => _isFreeAllDay(b, allBookings, blackouts)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Bus calendar')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dayNav(),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${trips.length} ${trips.length == 1 ? 'trip' : 'trips'} · '
                '$freeCount ${freeCount == 1 ? 'bus' : 'buses'} free all day',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              const Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.sm,
                children: [
                  _Legend(color: AppColors.primaryTint, label: 'Available'),
                  _Legend(color: AppColors.accent, label: 'Hold'),
                  _Legend(color: AppColors.primary, label: 'Confirmed / in trip'),
                  _Legend(color: AppColors.surfaceAlt, label: 'Completed'),
                  _Legend(color: AppColors.urgentTint, label: 'Blacked out'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _hourRuler(),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  children: [
                    for (final bus in buses) _busRow(bus, allBookings, blackouts),
                    if (buses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxl),
                        child: Text('No active buses in the fleet.',
                            style: textTheme.bodyMedium, textAlign: TextAlign.center),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    const HairlineDivider(),
                    const SectionLabel("Today's trips"),
                    if (trips.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text('No trips on this day.', style: textTheme.bodyMedium),
                      )
                    else
                      for (final booking in trips)
                        BookingCard(booking: booking, onTap: () => _openBooking(booking)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AdminBottomNav(currentIndex: 1, onTap: _onNavTap),
    );
  }

  Widget _dayNav() {
    final textTheme = Theme.of(context).textTheme;
    final isToday = dateOnly(_day) == dateOnly(ref.watch(clockProvider)());
    return Row(
      children: [
        _arrow(Icons.chevron_left_rounded, () => _shift(-1)),
        Expanded(
          child: Material(
            color: AppColors.primaryTint,
            borderRadius: AppRadius.controlRadius,
            child: InkWell(
              borderRadius: AppRadius.controlRadius,
              onTap: _pickDay,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        AppDateFormat.weekdayDayMonth(_day),
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(color: AppColors.primary),
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 6),
                      Text('· Today', style: textTheme.labelMedium?.copyWith(color: AppColors.primary)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        _arrow(Icons.chevron_right_rounded, () => _shift(1)),
      ],
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) => Material(
        color: AppColors.surface,
        borderRadius: AppRadius.controlRadius,
        child: InkWell(
          borderRadius: AppRadius.controlRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Icon(icon, size: 22, color: AppColors.textSecondary),
          ),
        ),
      );

  Widget _hourRuler() {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 14,
          child: Stack(
            children: [
              for (var hour = _rulerStart.toInt(); hour <= _rulerEnd.toInt(); hour += 3)
                Positioned(
                  left: _offsetFor(hour.toDouble(), width) - 8,
                  child: Text(AppDateFormat.hourTick(hour), style: textTheme.labelSmall),
                ),
            ],
          ),
        );
      },
    );
  }

  double _offsetFor(double hour, double width) =>
      (((hour - _rulerStart) / (_rulerEnd - _rulerStart)).clamp(0.0, 1.0)) * width;

  double _hourOf(DateTime t, DateTime day) {
    if (t.isBefore(dateOnly(day))) return _rulerStart;
    if (!t.isBefore(dateOnly(day).add(const Duration(days: 1)))) return _rulerEnd;
    return t.hour + t.minute / 60;
  }

  /// Fill, border and label colour for a booking bar, by stage — a hold
  /// reads as visibly provisional, a live trip as solid, a finished one
  /// as quiet, so the timeline tells stage apart from occupancy at a glance.
  (Color, Color, Color) _barColors(BookingStage stage) {
    switch (stage) {
      case BookingStage.requested:
      case BookingStage.costConfirmed:
        return (AppColors.accentTint, AppColors.accent, AppColors.accent);
      case BookingStage.confirmed:
      case BookingStage.inTrip:
        return (AppColors.primary, AppColors.primary, AppColors.onPrimary);
      case BookingStage.completed:
      case BookingStage.settled:
      case BookingStage.expired:
      case BookingStage.cancelled:
        return (AppColors.surfaceAlt, AppColors.border, AppColors.textSecondary);
    }
  }

  Widget _busRow(BusRecord bus, List<Booking> allBookings, List<BlackoutEntry> allBlackouts) {
    final textTheme = Theme.of(context).textTheme;
    final window = availabilityFor(bus, _day);
    final blackout = blackoutOn(bus.id, _day, allBlackouts);
    final isBlackedOut = blackout != null;
    final bookings = bookingsFor(bus.id, _day, allBookings);

    final String caption;
    if (isBlackedOut) {
      caption = 'Blacked out · ${blackout.reason}';
    } else if (!window.available) {
      caption = 'Unavailable';
    } else if (bookings.isEmpty) {
      caption = 'Free all day · ${AppDateFormat.timeRange(window.start, window.end)}';
    } else {
      caption = 'Available ${AppDateFormat.timeRange(window.start, window.end)}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: AppRadius.tagRadius,
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BusFormScreen(bus: bus)));
              if (mounted) setState(() {});
            },
            child: Row(
              children: [
                Expanded(child: Text(bus.label, style: textTheme.titleSmall)),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return SizedBox(
                height: _trackHeight,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: AppRadius.tagRadius,
                      ),
                    ),
                    if (isBlackedOut)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.urgentTint,
                          borderRadius: AppRadius.tagRadius,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          blackout.isMaintenance ? 'Maintenance' : 'Blacked out',
                          style: textTheme.labelSmall?.copyWith(color: AppColors.urgent),
                        ),
                      )
                    else if (window.available) ...[
                      Positioned(
                        left: _offsetFor(window.start.hour + window.start.minute / 60, width),
                        width: (_offsetFor(window.end.hour + window.end.minute / 60, width) -
                                _offsetFor(window.start.hour + window.start.minute / 60, width))
                            .clamp(0.0, width),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: AppRadius.tagRadius,
                          ),
                        ),
                      ),
                      for (final booking in bookings)
                        Positioned(
                          left: _offsetFor(_hourOf(booking.start, _day), width),
                          width: (_offsetFor(_hourOf(booking.end, _day), width) -
                                  _offsetFor(_hourOf(booking.start, _day), width))
                              .clamp(0.0, width),
                          top: 0,
                          bottom: 0,
                          child: Builder(builder: (context) {
                            final (fill, border, labelColor) = _barColors(booking.stage);
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: AppRadius.tagRadius,
                                onTap: () => _openBooking(booking),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: fill,
                                    border: Border.all(color: border, width: 1),
                                    borderRadius: AppRadius.tagRadius,
                                  ),
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      booking.reference,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.labelSmall
                                          ?.copyWith(color: labelColor, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                    ] else
                      Center(
                        child: Text('Unavailable',
                            style: textTheme.labelSmall?.copyWith(color: AppColors.textTertiary)),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(caption, style: textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
