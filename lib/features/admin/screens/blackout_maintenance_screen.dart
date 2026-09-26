import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_atoms.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/date_time_field.dart';
import '../../../data/mock_data.dart';
import '../../../data/models.dart';

/// BUS-04: blackout dates and maintenance windows, set by Admin only.
/// These are BLACKOUT / MAINTENANCE blocks in the availability engine
/// (BRD Section 5.1) — a bus is excluded from search for their span.
class BlackoutMaintenanceScreen extends StatefulWidget {
  const BlackoutMaintenanceScreen({super.key});

  @override
  State<BlackoutMaintenanceScreen> createState() => _BlackoutMaintenanceScreenState();
}

String busLabelFor(String reg) {
  for (final bus in MockData.buses) {
    if (bus.regNumber == reg) return bus.label;
  }
  return reg;
}

class _BlackoutMaintenanceScreenState extends State<BlackoutMaintenanceScreen> {
  Future<void> _addBlock() async {
    final entry = await showModalBottomSheet<BlackoutEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddBlackoutSheet(),
    );
    if (entry != null) setState(() => MockData.blackouts.add(entry));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Blackout & maintenance')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBlock,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add block'),
      ),
      body: SafeArea(
        child: MockData.blackouts.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxl),
                child: Text('No blackouts or maintenance windows.',
                    style: textTheme.bodyMedium, textAlign: TextAlign.center),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
                itemCount: MockData.blackouts.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) {
                  final b = MockData.blackouts[i];
                  return AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: b.isMaintenance
                                ? AppColors.warningTint
                                : AppColors.textPrimary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            b.isMaintenance ? Icons.build_rounded : Icons.block_rounded,
                            size: 17,
                            color: b.isMaintenance ? AppColors.warning : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(busLabelFor(b.busReg), style: textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(b.reason, style: textTheme.bodyMedium),
                              Text(
                                '${AppDateFormat.dayMonth(b.from)} – ${AppDateFormat.dayMonth(b.to)}',
                                style: textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => MockData.blackouts.removeAt(i)),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _AddBlackoutSheet extends StatefulWidget {
  const _AddBlackoutSheet();

  @override
  State<_AddBlackoutSheet> createState() => _AddBlackoutSheetState();
}

class _AddBlackoutSheetState extends State<_AddBlackoutSheet> {
  final _reason = TextEditingController();
  String? _bus;
  bool _isMaintenance = false;
  DateTime _from = DateTime(2026, 9, 20);
  DateTime _to = DateTime(2026, 9, 21);

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

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
          Text('Block a bus', style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.controlRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _bus,
                isExpanded: true,
                hint: const Text('Select bus'),
                items: MockData.buses
                    .map((b) => DropdownMenuItem(value: b.regNumber, child: Text(b.regNumber)))
                    .toList(),
                onChanged: (v) => setState(() => _bus = v),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: DateField(label: 'From', value: _from, onChanged: (v) => setState(() => _from = v))),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: DateField(label: 'To', value: _to, firstDate: _from, onChanged: (v) => setState(() => _to = v))),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          LabeledField(label: 'Reason', controller: _reason),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Checkbox(
                value: _isMaintenance,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _isMaintenance = v ?? false),
              ),
              Text('This is a maintenance window', style: textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Add block',
            onPressed: _bus == null
                ? null
                : () => Navigator.of(context).pop(BlackoutEntry(
                      busReg: _bus!,
                      reason: _reason.text.trim().isEmpty ? 'Blocked by admin' : _reason.text.trim(),
                      from: _from,
                      to: _to,
                      isMaintenance: _isMaintenance,
                    )),
          ),
        ],
      ),
    );
  }
}
