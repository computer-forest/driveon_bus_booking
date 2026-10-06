import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/status_stepper.dart';
import '../../../data/ids.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../widgets/customer_bottom_nav.dart';
import '../widgets/driver_card.dart';
import 'home_search_screen.dart';
import 'my_bookings_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'rating_screen.dart';

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.booking});

  /// The booking as it was when the screen opened; the live copy from the
  /// backend replaces it as soon as one is available.
  final Booking booking;

  static const _steps = ['Requested', 'Cost set', 'Confirmed', 'In trip', 'Done'];

  static int _stepFor(BookingStage stage) {
    switch (stage) {
      case BookingStage.requested:
        return 0;
      case BookingStage.costConfirmed:
        return 1;
      case BookingStage.confirmed:
        return 2;
      case BookingStage.inTrip:
        return 3;
      case BookingStage.completed:
      case BookingStage.settled:
        return 4;
    }
  }

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeSearchScreen()),
          (route) => false,
        );
      case 1:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
      case 2:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      case 3:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    }
  }

  Future<void> _requestCancellation(BuildContext context, WidgetRef ref, Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request cancellation?'),
        content: const Text(
          "This sends a cancellation request to our team — the booking stays active until Admin processes it.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Back')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Request')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final user = ref.read(authStateProvider).value;
      await ref.read(cancellationRepositoryProvider).request(
            CancellationRequest(
              id: newId('cnl'),
              bookingId: booking.id,
              requestedBy: user?.id ?? '',
              createdAt: ref.read(clockProvider)(),
            ),
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancellation requested — our team will confirm shortly.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final live = ref.watch(bookingsProvider).items.where((b) => b.id == booking.id);
    final current = live.isEmpty ? booking : live.first;
    final bus = ref.watch(busesProvider).items.where((b) => b.id == current.busId).firstOrNull;
    // Driver records (with phone numbers) are staff-only. A customer sees the
    // driver's name from the bus; the number is added to the booking itself
    // when staff confirm it (Stage 4/5).
    final staffDriver = ref
        .watch(driversProvider)
        .items
        .where((d) => d.id == bus?.driverId)
        .firstOrNull;
    final driver = bus == null || bus.driverId == null
        ? null
        : DriverInfo(name: staffDriver?.name ?? bus.driverName, phone: staffDriver?.phone ?? '', busNumber: bus.regNumber);
    final payments = ref.watch(paymentsForBookingProvider(current.id)).items;
    final ledger = _ledgerFor(current, payments);
    return Scaffold(
      appBar: AppBar(title: const Text('Booking detail')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(current.route, style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${AppDateFormat.dayMonthYear(current.start)}, '
                    '${AppDateFormat.hourMinute(TimeOfDay.fromDateTime(current.start))}',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: AppRadius.tagRadius,
                    ),
                    child: Text(
                      'BOOKING REF · ${current.reference}',
                      style: textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  StatusStepper(steps: _steps, currentIndex: _stepFor(current.stage)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionLabel('Your bus and driver'),
            AppCard(
              child: driver == null
                  ? Text('Your driver will be shared once the booking is confirmed.', style: textTheme.bodyMedium)
                  : DriverCard(driver: driver),
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(label: 'Open GPS link', icon: Icons.location_on_outlined, onPressed: () {}),
            const SizedBox(height: AppSpacing.xxl),
            const SectionLabel('Payment'),
            AppCard(
              child: Column(
                children: [
                  for (final entry in ledger) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.label, style: textTheme.bodyLarge),
                            if (entry.note != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(entry.note!, style: textTheme.labelSmall),
                              ),
                          ],
                        ),
                        Text(
                          entry.amount,
                          style: textTheme.titleSmall?.copyWith(
                            color: entry == ledger.last ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (entry != ledger.last) const HairlineDivider(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            SecondaryButton(
              label: 'Rate this trip',
              icon: Icons.star_outline_rounded,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RatingScreen(booking: current))),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: () => _requestCancellation(context, ref, current),
                child: Text('Request cancellation', style: textTheme.labelLarge?.copyWith(color: AppColors.urgent)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomerBottomNav(currentIndex: 1, onTap: (i) => _onNavTap(context, i)),
    );
  }

  /// What the customer sees under Payment: the fare, each payment an admin
  /// recorded, and what is still owed. Nothing here is calculated beyond
  /// reading the booking's own totals.
  static List<LedgerEntry> _ledgerFor(Booking booking, List<Payment> payments) {
    return [
      LedgerEntry(label: 'Total fare', amount: AppMoneyFormat.rupees(booking.totalFare)),
      for (final p in payments)
        LedgerEntry(
          label: switch (p.kind) {
            PaymentKind.advance => 'Advance received',
            PaymentKind.balance => 'Balance received',
            PaymentKind.refund => 'Refund',
          },
          amount: AppMoneyFormat.rupees(p.amount),
          note: 'Recorded by ${p.recordedBy} · ${AppDateFormat.dayMonth(p.receivedOn)}',
        ),
      LedgerEntry(label: 'Balance due', amount: AppMoneyFormat.rupees(booking.balanceDue)),
    ];
  }
}
