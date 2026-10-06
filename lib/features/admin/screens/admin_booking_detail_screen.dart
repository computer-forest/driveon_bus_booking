import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/guarded_write.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/stage_badge.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/repositories.dart';
import 'cancel_refund_screen.dart';
import 'reallocation_picker_screen.dart';

class AdminBookingDetailScreen extends ConsumerStatefulWidget {
  const AdminBookingDetailScreen({super.key, required this.booking});

  /// The booking as it was when the screen opened; the live copy from the
  /// backend replaces it as soon as one is available.
  final Booking booking;

  @override
  ConsumerState<AdminBookingDetailScreen> createState() => _AdminBookingDetailScreenState();
}

class _AdminBookingDetailScreenState extends ConsumerState<AdminBookingDetailScreen> {
  late final _totalFare = TextEditingController(
    text: widget.booking.totalFare == 0 ? '' : '${widget.booking.totalFare}',
  );
  late final _advanceDue = TextEditingController(text: _advanceText(widget.booking.totalFare));
  late final _paymentAmount = TextEditingController(text: _advanceText(widget.booking.totalFare));
  final _paymentMode = TextEditingController(text: 'UPI');
  final _paymentReference = TextEditingController();
  final _balanceReceived = TextEditingController();

  String _advanceText(int totalFare) {
    final advance = ref.read(appConfigProvider).config.advanceFor(totalFare);
    return advance == 0 ? '' : '$advance';
  }

  @override
  void dispose() {
    _totalFare.dispose();
    _advanceDue.dispose();
    _paymentAmount.dispose();
    _paymentMode.dispose();
    _paymentReference.dispose();
    _balanceReceived.dispose();
    super.dispose();
  }

  static int _rupees(String text) => int.tryParse(text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  Booking get _current {
    final live = ref.read(bookingsProvider).items.where((b) => b.id == widget.booking.id);
    return live.isEmpty ? widget.booking : live.first;
  }

  BookingRepository get _bookings => ref.read(bookingRepositoryProvider);

  void _note(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Writes the fare and moves a fresh request to "cost confirmed".
  Future<void> _confirmCost() async {
    final fare = _rupees(_totalFare.text);
    final saved = await guardedWrite(context, () => _bookings.confirmCost(widget.booking.id, fare));
    if (saved) _note('Cost saved.');
  }

  /// Records the advance the customer paid outside the app and confirms.
  Future<void> _recordAdvanceAndConfirm() async {
    final mode = _paymentMode.text.trim();
    await guardedWrite(
      context,
      () => _bookings.recordAdvance(
        widget.booking.id,
        amount: _rupees(_paymentAmount.text),
        mode: mode.isEmpty ? 'UPI' : mode,
        reference: _paymentReference.text.trim(),
      ),
    );
  }

  Future<void> _settle() async {
    await guardedWrite(
      context,
      () => _bookings.recordBalance(widget.booking.id, amount: _rupees(_balanceReceived.text)),
    );
  }

  Future<void> _reallocate() async {
    final b = _current;
    final newBus = await Navigator.of(context).push<BusRecord>(
      MaterialPageRoute(
        builder: (_) => ReallocationPickerScreen(currentBusId: b.busId, start: b.start, end: b.end),
      ),
    );
    if (newBus == null || !mounted) return;
    final moved = await guardedWrite(context, () => _bookings.reallocate(b.id, newBus.id));
    if (moved) _note('Moved to ${newBus.regNumber}.');
  }

  Future<void> _cancel() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CancelRefundScreen(reference: widget.booking.reference)),
    );
    if (result == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    ref.watch(bookingsProvider);
    final booking = _current;
    final stage = booking.stage;
    final now = ref.watch(clockProvider)();
    final secondsLeft = booking.holdSecondsLeft(now);
    return Scaffold(
      appBar: AppBar(title: Text(booking.reference)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxxl),
          children: [
            if (booking.isHold) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.urgentTint,
                  borderRadius: AppRadius.controlRadius,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_bottom_rounded, size: 16, color: AppColors.urgent),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Held for ${(secondsLeft ~/ 60).toString().padLeft(2, '0')}:'
                      '${(secondsLeft % 60).toString().padLeft(2, '0')} more',
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.urgent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Customer'),
                  Text(booking.customerName, style: textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(booking.customerPhone, style: textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
                  const HairlineDivider(),
                  const SectionLabel('Requested'),
                  Text(booking.route, style: textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    '${AppDateFormat.dayMonthYear(booking.start)}, '
                    '${AppDateFormat.timeRange(TimeOfDay.fromDateTime(booking.start), TimeOfDay.fromDateTime(booking.end))} · '
                    '${booking.capacity} seater · ${booking.busReg}',
                    style: textTheme.bodyMedium,
                  ),
                  if (booking.pickupLandmark != null) ...[
                    const SizedBox(height: 2),
                    Text('Pickup: ${booking.pickupLandmark}', style: textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            const SectionLabel('Confirm cost'),
            LabeledField(
              label: 'Total fare (₹)',
              controller: _totalFare,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                _advanceDue.text = _advanceText(_rupees(v));
                setState(() {});
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(
              label: 'Advance due (₹) — ${ref.watch(appConfigProvider).config.defaultAdvancePercent}% default',
              controller: _advanceDue,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.lg),
            SecondaryButton(
              label: 'Save & notify customer',
              onPressed: _rupees(_totalFare.text) > 0 ? _confirmCost : null,
            ),
            const SizedBox(height: AppSpacing.xxl),

            const SectionLabel('Record payment'),
            Row(
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Amount (₹)',
                    controller: _paymentAmount,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: LabeledField(label: 'Mode', controller: _paymentMode)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(label: 'Reference', controller: _paymentReference, hint: 'UPI / receipt number'),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Confirm booking',
              onPressed: stage == BookingStage.requested || stage == BookingStage.costConfirmed
                  ? _recordAdvanceAndConfirm
                  : null,
            ),
            const SizedBox(height: AppSpacing.xxl),

            SectionLabel('Trip', trailing: StageBadge(stage)),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Start trip',
                      icon: Icons.play_arrow_rounded,
                      onPressed: stage == BookingStage.confirmed
                          ? () => guardedWrite(context, () => _bookings.startTrip(booking.id))
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Complete trip',
                      icon: Icons.flag_rounded,
                      onPressed: stage == BookingStage.inTrip
                          ? () async {
                              _balanceReceived.text = '${booking.balanceDue}';
                              await guardedWrite(context, () => _bookings.completeTrip(booking.id));
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            if (stage == BookingStage.completed) ...[
              const SizedBox(height: AppSpacing.lg),
              LabeledField(
                label: 'Balance received (₹)',
                controller: _balanceReceived,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Record balance & settle', onPressed: _settle),
            ],
            const SizedBox(height: AppSpacing.xxl),

            Center(
              child: TextButton.icon(
                onPressed: _reallocate,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Reallocate bus'),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: _cancel,
                icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.urgent),
                label: Text('Cancel booking', style: textTheme.labelLarge?.copyWith(color: AppColors.urgent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
