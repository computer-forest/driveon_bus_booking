import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import 'cancel_refund_screen.dart';

/// CAN-02: customers ask to cancel, staff decide. Pending requests come
/// first; decided ones stay below as a record.
class CancellationRequestsScreen extends ConsumerWidget {
  const CancellationRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final bookings = {for (final b in ref.watch(bookingsProvider).items) b.id: b};
    final now = ref.watch(clockProvider)();
    return Scaffold(
      appBar: AppBar(title: const Text('Cancellation requests')),
      body: SafeArea(
        child: AsyncBody<List<CancellationRequest>>(
          value: ref.watch(cancellationsProvider),
          builder: (requests) {
            final sorted = [...requests]..sort((a, b) {
                final byStatus = (a.status == CancellationStatus.pending ? 0 : 1) - (b.status == CancellationStatus.pending ? 0 : 1);
                return byStatus != 0 ? byStatus : b.createdAt.compareTo(a.createdAt);
              });
            if (sorted.isEmpty) {
              return Center(child: Text('No cancellation requests.', style: textTheme.bodyMedium));
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final r = sorted[i];
                final booking = bookings[r.bookingId];
                final pending = r.status == CancellationStatus.pending;
                return AppCard(
                  onTap: pending && booking != null
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => CancelRefundScreen(booking: booking, request: r)),
                          )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(booking?.reference ?? 'Booking', style: textTheme.titleSmall),
                          ),
                          StatusBadge(
                            label: switch (r.status) {
                              CancellationStatus.pending => 'Needs a decision',
                              CancellationStatus.approved => 'Cancelled',
                              CancellationStatus.declined => 'Declined',
                            },
                            tone: switch (r.status) {
                              CancellationStatus.pending => StatusTone.urgent,
                              CancellationStatus.approved => StatusTone.neutral,
                              CancellationStatus.declined => StatusTone.info,
                            },
                          ),
                        ],
                      ),
                      if (booking != null) ...[
                        const SizedBox(height: 2),
                        Text('${booking.customerName} · ${booking.route}', style: textTheme.bodyMedium),
                        Text(
                          '${AppDateFormat.dayMonthYear(booking.start)} · paid ${AppMoneyFormat.rupees(booking.amountPaid)}',
                          style: textTheme.labelMedium,
                        ),
                      ],
                      if (r.reason.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('"${r.reason}"', style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                      ],
                      if (r.status == CancellationStatus.approved && r.refundAmount > 0)
                        Text('Refunded ${AppMoneyFormat.rupees(r.refundAmount)}', style: textTheme.labelMedium),
                      if (r.decisionNote.isNotEmpty) Text('Note: ${r.decisionNote}', style: textTheme.labelMedium),
                      const SizedBox(height: 4),
                      Text('Requested ${AppDateFormat.ago(r.createdAt, now)}', style: textTheme.labelSmall),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
