import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models.dart';
import 'hold_screen.dart';

/// Shared by the results list's "Select this bus" fast path and the bus
/// detail screen: shows the hold confirmation sheet, and pushes
/// [HoldScreen] if the customer confirms. Returns once navigation settles.
Future<void> confirmBusSelection(BuildContext context, {required BusRecord bus, required String routeSummary}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _SelectionConfirmationSheet(bus: bus, routeSummary: routeSummary),
  );
  if (confirmed == true && context.mounted) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HoldScreen()));
  }
}

class BusDetailScreen extends StatelessWidget {
  const BusDetailScreen({super.key, required this.bus, required this.routeSummary});

  final BusRecord bus;
  final String routeSummary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('${bus.capacity} seater')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.containerRadius,
                    child: SizedBox(
                      height: 180,
                      child: PageView.builder(
                        itemCount: bus.photoCount,
                        itemBuilder: (context, i) => Container(
                          color: AppColors.surface,
                          alignment: Alignment.center,
                          child: const Icon(Icons.directions_bus_filled_rounded, size: 56, color: AppColors.textTertiary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${bus.capacity} seater', style: textTheme.headlineSmall),
                      const StatusBadge(label: 'Available', tone: StatusTone.success),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(routeSummary, style: textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionLabel('Amenities'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: bus.amenities
                        .map((a) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadius.controlRadius,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(a, style: textTheme.labelMedium?.copyWith(color: AppColors.textPrimary)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionLabel('Good to know'),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(Icons.bolt_rounded, 'Held immediately on selection, before Admin confirms.'),
                        const SizedBox(height: AppSpacing.sm),
                        _infoRow(Icons.call_outlined, "Our team calls within minutes to confirm the fare."),
                        const SizedBox(height: AppSpacing.sm),
                        _infoRow(Icons.payments_outlined, 'No payment happens in the app.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: PrimaryButton(
                label: 'Select this bus',
                onPressed: () => confirmBusSelection(context, bus: bus, routeSummary: routeSummary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Builder(builder: (context) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      );
    });
  }
}

class _SelectionConfirmationSheet extends StatelessWidget {
  const _SelectionConfirmationSheet({required this.bus, required this.routeSummary});

  final BusRecord bus;
  final String routeSummary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Hold this bus?', style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "We'll hold the ${bus.capacity} seater for $routeSummary right away, so nobody else can take it while our team calls to confirm the cost.",
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(label: 'Hold this bus', onPressed: () => Navigator.of(context).pop(true)),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(label: 'Not now', onPressed: () => Navigator.of(context).pop(false)),
        ],
      ),
    );
  }
}
