import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../utils/date_format.dart';

/// A [LabeledField]-styled control that opens the platform date picker
/// (themed to match the brand) instead of the keyboard, and renders the
/// result the same way static copy is formatted elsewhere ("14 Sep 2026").
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: firstDate ?? DateTime.now().subtract(const Duration(days: 1)),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => _PickerTheme(child: child!),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return _PickerField(
      label: label,
      value: AppDateFormat.dayMonthYear(value),
      icon: Icons.calendar_today_outlined,
      onTap: () => _pick(context),
    );
  }
}

/// A [LabeledField]-styled control that opens the platform time picker.
class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: value,
      builder: (context, child) => _PickerTheme(child: child!),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return _PickerField(
      label: label,
      value: AppDateFormat.hourMinute(value),
      icon: Icons.schedule_outlined,
      onTap: () => _pick(context),
    );
  }
}

/// Re-tints the default Material picker to the app's brand colour so it
/// doesn't look like a stock system dialog dropped into the flow.
class _PickerTheme extends StatelessWidget {
  const _PickerTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
        ),
      ),
      child: child,
    );
  }
}

class _PickerField extends StatefulWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_PickerField> createState() => _PickerFieldState();
}

class _PickerFieldState extends State<_PickerField> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Material(
            color: AppColors.surface,
            borderRadius: AppRadius.controlRadius,
            child: InkWell(
              borderRadius: AppRadius.controlRadius,
              onTap: widget.onTap,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.controlRadius,
                  border: Border.all(color: _pressed ? AppColors.primary : AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(widget.value, style: textTheme.bodyLarge)),
                    Icon(widget.icon, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
