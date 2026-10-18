import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/guarded_write.dart';
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
import '../../../core/utils/contact_launcher.dart';
import '../widgets/driver_card.dart';
import 'home_search_screen.dart';
import 'my_bookings_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'rating_screen.dart';

/// Only a web link is ever opened.
Uri? _httpsUri(String? raw) {
  final u = raw == null ? null : Uri.tryParse(raw.trim());
  return u != null && u.scheme == 'https' && u.host.isNotEmpty ? u : null;
}

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.booking});

  /// The booking as it was when the screen opened; the live copy from the
  /// backend replaces it as soon as one is available.
  final Booking booking;

  static const _steps = [
    'Requested',
    'Cost set',
    'Confirmed',
    'In trip',
    'Done'
  ];

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
      case BookingStage.expired:
      case BookingStage.cancelled:
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
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
      case 2:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      case 3:
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    }
  }

  Future<void> _requestCancellation(
      BuildContext context, WidgetRef ref, Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request cancellation?'),
        content: const Text(
          "This sends a cancellation request to our team — the booking stays active until Admin processes it.",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Back')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Request')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final user = ref.read(authStateProvider).value;
      final saved = await guardedWrite(
        context,
        () => ref.read(cancellationRepositoryProvider).request(
              CancellationRequest(
                id: newId('cnl'),
                bookingId: booking.id,
                requestedBy: user?.id ?? '',
                createdAt: ref.read(clockProvider)(),
              ),
            ),
      );
      if (!saved || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Cancellation requested — our team will confirm shortly.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final live =
        ref.watch(bookingsProvider).items.where((b) => b.id == booking.id);
    final current = live.isEmpty ? booking : live.first;
    final bus = ref
        .watch(busesProvider)
        .items
        .where((b) => b.id == current.busId)
        .firstOrNull;
    // Driver records are staff-only, so the server copies the driver's number
    // and the tracking link onto the booking when staff confirm it.
    final live2 = current.stage == BookingStage.confirmed ||
        current.stage == BookingStage.inTrip;
    final driver = !live2 || bus == null || bus.driverId == null
        ? null
        : DriverInfo(
            name: bus.driverName,
            phone: current.driverPhone ?? '',
            busNumber: bus.regNumber);
    final gpsUri = live2 ? _httpsUri(current.gpsLink) : null;
    final payments = ref.watch(paymentsForBookingProvider(current.id)).items;
    final requests = ref
        .watch(cancellationsProvider)
        .items
        .where((r) => r.bookingId == current.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = requests.firstOrNull;
    final pending = latest?.status == CancellationStatus.pending;
    final cancellable = current.stage == BookingStage.requested ||
        current.stage == BookingStage.costConfirmed ||
        current.stage == BookingStage.confirmed;
    final ledger = _ledgerFor(current, payments);
    return Scaffold(
      appBar: AppBar(title: const Text('Booking detail')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: AppRadius.tagRadius,
                    ),
                    child: Text(
                      'BOOKING REF · ${current.reference}',
                      style: textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  StatusStepper(
                      steps: _steps, currentIndex: _stepFor(current.stage)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionLabel('Your bus and driver'),
            AppCard(
              child: driver == null
                  ? Text(
                      'Your driver and bus tracking link are shared once the booking is confirmed.',
                      style: textTheme.bodyMedium)
                  : DriverCard(driver: driver),
            ),
            const SizedBox(height: AppSpacing.md),
            if (gpsUri != null)
              SecondaryButton(
                label: 'Track the bus',
                icon: Icons.location_on_outlined,
                onPressed: () => openOrExplain(
                    context, ref.read(urlOpenerProvider), gpsUri,
                    what: 'the tracking link', number: ''),
              ),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.label, style: textTheme.bodyLarge),
                              if (entry.note != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(entry.note!,
                                      style: textTheme.labelSmall),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          entry.amount,
                          style: textTheme.titleSmall?.copyWith(
                            color: entry == ledger.last
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
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
            if (current.stage == BookingStage.completed ||
                current.stage == BookingStage.settled)
              SecondaryButton(
                label: 'Rate this trip',
                icon: Icons.star_outline_rounded,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RatingScreen(booking: current))),
              ),
            if (current.stage == BookingStage.cancelled ||
                current.stage == BookingStage.expired)
              Text(
                current.stage == BookingStage.cancelled
                    ? 'This booking was cancelled.'
                    : 'This hold ran out and the bus was released.',
                style: textTheme.bodyMedium,
              ),
            if (latest?.status == CancellationStatus.declined &&
                cancellable) ...[
              Text(
                'Your cancellation request was declined.${latest!.decisionNote.isEmpty ? '' : ' ${latest.decisionNote}'}',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (cancellable) ...[
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: pending
                      ? null
                      : () => _requestCancellation(context, ref, current),
                  child: Text(
                    pending
                        ? 'Cancellation requested — awaiting our team'
                        : 'Request cancellation',
                    style: textTheme.labelLarge?.copyWith(
                        color: pending
                            ? AppColors.textTertiary
                            : AppColors.urgent),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: CustomerBottomNav(
          currentIndex: 1, onTap: (i) => _onNavTap(context, i)),
    );
  }

  /// What the customer sees under Payment: the fare, each payment an admin
  /// recorded, and what is still owed. Nothing here is calculated beyond
  /// reading the booking's own totals.
  static List<LedgerEntry> _ledgerFor(Booking booking, List<Payment> payments) {
    return [
      LedgerEntry(
          label: 'Total fare',
          amount: AppMoneyFormat.rupees(booking.totalFare)),
      for (final p in payments)
        LedgerEntry(
          label: switch (p.kind) {
            PaymentKind.advance => 'Advance received',
            PaymentKind.balance => 'Balance received',
            PaymentKind.refund => 'Refund',
          },
          amount: AppMoneyFormat.rupees(p.amount),
          note:
              'Recorded by ${p.recordedBy} · ${AppDateFormat.dayMonth(p.receivedOn)}',
        ),
      LedgerEntry(
          label: 'Balance due',
          amount: AppMoneyFormat.rupees(booking.balanceDue)),
    ];
  }
}
