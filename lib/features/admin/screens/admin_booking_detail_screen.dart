import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/mock_data.dart';
import '../../../data/models.dart';
import '../widgets/booking_card.dart';
import 'cancel_refund_screen.dart';
import 'reallocation_picker_screen.dart';

class AdminBookingDetailScreen extends StatefulWidget {
  const AdminBookingDetailScreen({super.key, required this.booking});

  final Booking booking;

  @override
  State<AdminBookingDetailScreen> createState() => _AdminBookingDetailScreenState();
}

class _AdminBookingDetailScreenState extends State<AdminBookingDetailScreen> {
  late BookingStage _stage = widget.booking.stage;
  late String _busReg = widget.booking.busReg;
  late int _amountPaid = widget.booking.amountPaid;

  Future<void> _reallocate() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReallocationPickerScreen(
          currentBusReg: _busReg,
          start: widget.booking.start,
          end: widget.booking.end,
        ),
      ),
    );
    if (result == true && mounted) {
      final index = MockData.buses.indexWhere((b) => b.regNumber != _busReg && b.active);
      setState(() => _busReg = index >= 0 ? MockData.buses[index].regNumber : _busReg);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bus reallocated — customer notified with new bus and driver.')),
      );
    }
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
    final booking = widget.booking;
    final advanceDue = (booking.totalFare * 0.25).round();
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
                      'Held for ${(booking.holdSecondsLeft ~/ 60).toString().padLeft(2, '0')}:'
                      '${(booking.holdSecondsLeft % 60).toString().padLeft(2, '0')} more',
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
                    '${booking.capacity} seater · $_busReg',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            const SectionLabel('Confirm cost'),
            LabeledField(
              label: 'Total fare (₹)',
              initialValue: booking.totalFare == 0 ? '' : '${booking.totalFare}',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.lg),
            LabeledField(
              label: 'Advance due (₹) — 25% default',
              initialValue: advanceDue == 0 ? '' : '$advanceDue',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.lg),
            SecondaryButton(label: 'Save & notify customer', onPressed: () {}),
            const SizedBox(height: AppSpacing.xxl),

            const SectionLabel('Record payment'),
            Row(
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Amount (₹)',
                    initialValue: '$_amountPaid',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(child: LabeledField(label: 'Mode', initialValue: 'UPI')),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const LabeledField(label: 'Reference', initialValue: 'UPI/20260908...'),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Confirm booking',
              onPressed: _stage == BookingStage.requested
                  ? () => setState(() => _stage = BookingStage.confirmed)
                  : null,
            ),
            const SizedBox(height: AppSpacing.xxl),

            SectionLabel('Trip', trailing: _stageBadge()),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Start trip',
                      icon: Icons.play_arrow_rounded,
                      onPressed:
                          _stage == BookingStage.confirmed ? () => setState(() => _stage = BookingStage.inTrip) : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Complete trip',
                      icon: Icons.flag_rounded,
                      onPressed:
                          _stage == BookingStage.inTrip ? () => setState(() => _stage = BookingStage.completed) : null,
                    ),
                  ),
                ],
              ),
            ),
            if (_stage == BookingStage.completed) ...[
              const SizedBox(height: AppSpacing.lg),
              LabeledField(
                label: 'Balance received (₹)',
                initialValue: '${booking.totalFare - _amountPaid}',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Record balance & settle',
                onPressed: () => setState(() {
                  _amountPaid = booking.totalFare;
                  _stage = BookingStage.settled;
                }),
              ),
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

  Widget _stageBadge() {
    final (label, tone) = stageDisplay(_stage);
    return StatusBadge(label: label, tone: tone);
  }
}
