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

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _isYesterday(DateTime at, DateTime now) =>
      _sameDay(at, DateTime(now.year, now.month, now.day - 1));

  /// How long ago [at] was, as of [now]: "2 min ago", "1 hr ago",
  /// "Yesterday", then a plain date.
  static String ago(DateTime at, DateTime now) {
    final diff = now.difference(at);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (_sameDay(at, now)) return '${diff.inHours} hr ago';
    if (_isYesterday(at, now)) return 'Yesterday';
    return dayMonth(at);
  }

  /// "Today, 10:42 AM", "Yesterday, 06:02 PM", then "12 Sep, 03:40 PM".
  static String dayAndTime(DateTime at, DateTime now) {
    final time = hourMinute(TimeOfDay.fromDateTime(at));
    if (_sameDay(at, now)) return 'Today, $time';
    if (_isYesterday(at, now)) return 'Yesterday, $time';
    return '${dayMonth(at)}, $time';
  }

  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  static String dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';
}
