import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/mock_data.dart';
import '../../../data/models.dart';
import '../widgets/admin_bottom_nav.dart';
import 'booking_queue_screen.dart';
import 'bus_list_screen.dart';
import 'reports_screen.dart';

class BusCalendarScreen extends StatefulWidget {
  const BusCalendarScreen({super.key});

  @override
  State<BusCalendarScreen> createState() => _BusCalendarScreenState();
}

class _BusCalendarScreenState extends State<BusCalendarScreen> {
  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  DateTime _weekOf = DateTime(2026, 9, 14);

  Color _bg(CalendarBlockType type) {
    switch (type) {
      case CalendarBlockType.available:
        return AppColors.surface;
      case CalendarBlockType.booked:
        return AppColors.primary;
      case CalendarBlockType.buffer:
        return AppColors.primaryTint;
      case CalendarBlockType.blackout:
        return AppColors.textPrimary;
    }
  }

  Color _fg(CalendarBlockType type) {
    switch (type) {
      case CalendarBlockType.available:
        return AppColors.textTertiary;
      case CalendarBlockType.booked:
        return AppColors.onPrimary;
      case CalendarBlockType.buffer:
        return AppColors.primary;
      case CalendarBlockType.blackout:
        return AppColors.onPrimary;
    }
  }

  String _label(CalendarBlock block) {
    switch (block.type) {
      case CalendarBlockType.available:
        return '—';
      case CalendarBlockType.booked:
        return block.label ?? 'Booked';
      case CalendarBlockType.buffer:
        return 'Buffer';
      case CalendarBlockType.blackout:
        return '✕';
    }
  }

  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekOf,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _weekOf = picked);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bus calendar', style: textTheme.displaySmall?.copyWith(fontSize: 24)),
                  _WeekPickerChip(label: 'Week of ${AppDateFormat.weekdayDayMonth(_weekOf)}', onTap: _pickWeek),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: _days
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(d, style: textTheme.labelSmall),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView(
                  children: [
                    for (final row in MockData.calendarRows) ...[
                      Text(row.busLabel, style: textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: row.blocks
                            .map((b) => Expanded(
                                  child: Container(
                                    height: 36,
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: b.type == CalendarBlockType.booked ? null : _bg(b.type),
                                      gradient: b.type == CalendarBlockType.booked ? AppGradients.primary : null,
                                      borderRadius: AppRadius.tagRadius,
                                      border: b.type == CalendarBlockType.available
                                          ? Border.all(color: AppColors.border)
                                          : null,
                                      boxShadow: b.type == CalendarBlockType.booked
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primary.withValues(alpha: 0.25),
                                                blurRadius: 6,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _label(b),
                                      style: textTheme.labelSmall?.copyWith(
                                        color: _fg(b.type),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    Wrap(
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _legendItem(context, 'Available', AppColors.surface, border: true),
                        _legendItem(context, 'Booked', AppColors.primary),
                        _legendItem(context, 'Buffer', AppColors.primaryTint),
                        _legendItem(context, 'Blackout', AppColors.textPrimary),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AdminBottomNav(
        currentIndex: 1,
        onTap: (i) {
          switch (i) {
            case 0:
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BookingQueueScreen()));
            case 2:
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BusListScreen()));
            case 3:
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ReportsScreen()));
          }
        },
      ),
    );
  }

  Widget _legendItem(BuildContext context, String label, Color color, {bool border = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: border ? Border.all(color: AppColors.border) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _WeekPickerChip extends StatelessWidget {
  const _WeekPickerChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryTint,
      borderRadius: AppRadius.controlRadius,
      child: InkWell(
        borderRadius: AppRadius.controlRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
