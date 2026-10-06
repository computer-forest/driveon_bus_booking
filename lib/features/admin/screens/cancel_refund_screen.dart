import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/guarded_write.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/text_prompt_dialog.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';

/// CAN-01..05: only staff can cancel. It needs a reason, releases the bus
/// immediately, notifies the customer, and records any refund that was paid
/// back outside the app against the booking.
///
/// With a customer's [request] this is the answer to it: cancel (approve) or
/// decline with a note the customer will see.
class CancelRefundScreen extends ConsumerStatefulWidget {
  const CancelRefundScreen({super.key, required this.booking, this.request});

  final Booking booking;
  final CancellationRequest? request;

  @override
  ConsumerState<CancelRefundScreen> createState() => _CancelRefundScreenState();
}

class _CancelRefundScreenState extends ConsumerState<CancelRefundScreen> {
  late String? _reason = widget.request == null ? null : 'Customer requested';
  bool _refundApplicable = false;
  String _mode = 'UPI';
  final _refundAmount = TextEditingController();
  final _reference = TextEditingController();
  bool _working = false;

  static const _reasons = [
    'Customer requested',
    'Bus unavailable',
    'Duplicate booking',
    'Other',
  ];

  @override
  void dispose() {
    _refundAmount.dispose();
    _reference.dispose();
    super.dispose();
  }

  int get _refund => _refundApplicable ? int.tryParse(_refundAmount.text.replaceAll(RegExp(r'\D'), '')) ?? 0 : 0;

  String? get _refundProblem {
    if (!_refundApplicable) return null;
    if (_refund <= 0) return 'Enter the amount paid back.';
    if (_refund > widget.booking.amountPaid) {
      return 'That is more than was paid (${AppMoneyFormat.rupees(widget.booking.amountPaid)}).';
    }
    return null;
  }

  bool get _canSubmit => _reason != null && _refundProblem == null && !_working;

  Future<void> _cancel() async {
    setState(() => _working = true);
    final saved = await guardedWrite(
      context,
      () => ref.read(bookingRepositoryProvider).cancel(
            widget.booking.id,
            reason: _reason!,
            refundAmount: _refund,
            mode: _mode,
            reference: _reference.text.trim(),
            requestId: widget.request?.id,
          ),
    );
    if (!mounted) return;
    setState(() => _working = false);
    if (saved) Navigator.of(context).pop(true);
  }

  Future<void> _decline() async {
    final note = await showTextPrompt(
      context,
      title: 'Decline this request?',
      hint: 'Tell the customer why (optional)',
      confirmLabel: 'Decline',
    );
    if (note == null || !mounted) return;
    setState(() => _working = true);
    final saved = await guardedWrite(
      context,
      () => ref.read(bookingRepositoryProvider).declineCancellation(
            widget.booking.id,
            requestId: widget.request!.id,
            note: note,
          ),
    );
    if (!mounted) return;
    setState(() => _working = false);
    if (saved) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final booking = widget.booking;
    final request = widget.request;
    return Scaffold(
      appBar: AppBar(title: Text('Cancel ${booking.reference}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          children: [
            if (request != null) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${booking.customerName} asked to cancel', style: textTheme.titleSmall),
                    if (request.reason.isNotEmpty) Text('"${request.reason}"', style: textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: AppColors.urgentTint, borderRadius: AppRadius.controlRadius),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.urgent, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'This releases the bus immediately and notifies the customer.',
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.urgent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Reason for cancellation'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _reasons.map((r) {
                final selected = _reason == r;
                return ChoiceChip(
                  label: Text(r),
                  selected: selected,
                  onSelected: (_) => setState(() => _reason = r),
                  selectedColor: AppColors.primary,
                  labelStyle: textTheme.labelMedium?.copyWith(color: selected ? AppColors.onPrimary : AppColors.textPrimary),
                  side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Refund applicable', style: textTheme.titleSmall),
                        Text(
                          booking.amountPaid > 0
                              ? 'Paid so far: ${AppMoneyFormat.rupees(booking.amountPaid)}. Refunds happen outside the app — record what was paid back.'
                              : 'Nothing has been paid on this booking.',
                          style: textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _refundApplicable,
                    activeThumbColor: AppColors.primary,
                    onChanged: booking.amountPaid > 0 ? (v) => setState(() => _refundApplicable = v) : null,
                  ),
                ],
              ),
            ),
            if (_refundApplicable) ...[
              const SizedBox(height: AppSpacing.lg),
              LabeledField(
                label: 'Refund amount (₹)',
                controller: _refundAmount,
                keyboardType: TextInputType.number,
                errorText: _refundAmount.text.isEmpty ? null : _refundProblem,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Mode'),
                items: ['UPI', 'Bank transfer', 'Cash'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _mode = v ?? _mode),
              ),
              const SizedBox(height: AppSpacing.lg),
              LabeledField(label: 'Reference', controller: _reference, hint: 'UPI / transfer number'),
            ],
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _canSubmit ? _cancel : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.urgent,
                  side: const BorderSide(color: AppColors.urgent),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(_working ? 'Working…' : (request == null ? 'Cancel booking' : 'Approve and cancel booking')),
              ),
            ),
            if (request != null) ...[
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(label: 'Decline request', onPressed: _working ? null : _decline),
            ],
          ],
        ),
      ),
    );
  }
}
