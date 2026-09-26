import 'package:flutter/material.dart';

/// Hand-rolled date/time formatting so every screen renders dates the same
/// way ("14 Sep 2026", "06:00 AM") without pulling in intl for a UI-only
/// prototype.
class AppDateFormat {
  AppDateFormat._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String dayMonthYear(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String weekdayDayMonth(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

  static String hourMinute(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  static String timeRange(TimeOfDay from, TimeOfDay to) =>
      '${hourMinute(from)} – ${hourMinute(to)}';

  /// Compact hour label for the calendar's ruler — "6a", "12p", "9p".
  static String hourTick(int hour24) {
    final period = hour24 < 12 ? 'a' : 'p';
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour$period';
  }

  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  static String dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';
}
