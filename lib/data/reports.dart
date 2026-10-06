import '../core/utils/money_format.dart';
import 'availability.dart';
import 'models.dart';

/// The window a report covers. "Week" and "month" are the last 7 and 30 days
/// ending today, so the label always means what it says.
enum ReportPeriod {
  today('Today', 1),
  week('This week', 7),
  month('This month', 30);

  const ReportPeriod(this.label, this.days);
  final String label;
  final int days;
}

class VendorStat {
  const VendorStat({required this.name, required this.bookings});
  final String name;
  final int bookings;
}

class Report {
  const Report({required this.metrics, required this.vendors});
  final List<ReportMetric> metrics;
  final List<VendorStat> vendors;
}

class _Range {
  _Range(this.start, this.end);
  final DateTime start; // inclusive
  final DateTime end; // exclusive
  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

/// Works out the figures staff see, from the real records.
///
///  - Requests: holds created in the period (against the previous period of
///    the same length).
///  - Confirmed: bookings confirmed in the period.
///  - Collected: advance and balance received, less refunds, in the period.
///  - Outstanding: what confirmed, running and finished-but-unsettled
///    bookings still owe, as of now (not period-bound).
///  - Fleet utilisation: of the days each active bus was open for charter in
///    the period, the share on which it had a booking.
///  - Failed searches: searches that found no bus in the period.
///  - Hold-to-confirm: average time between holding and staff confirming.
Report buildReport({
  required ReportPeriod period,
  required DateTime now,
  required Iterable<Booking> bookings,
  required Iterable<Payment> payments,
  required Iterable<BusRecord> buses,
  required Iterable<Vendor> vendors,
  required Iterable<DateTime> searchMisses,
}) {
  final today = dateOnly(now);
  final range = _Range(today.subtract(Duration(days: period.days - 1)), today.add(const Duration(days: 1)));
  final previous = _Range(range.start.subtract(Duration(days: period.days)), range.start);

  // Bookings the server created before it recorded timestamps fall back to
  // their trip date.
  DateTime created(Booking b) => b.createdAt ?? b.start;

  final requests = bookings.where((b) => range.contains(created(b))).length;
  final previousRequests = bookings.where((b) => previous.contains(created(b))).length;
  final delta = requests - previousRequests;

  final confirmedThisPeriod = bookings.where((b) {
    final at = b.confirmedAt;
    if (at != null) return range.contains(at);
    const confirmedOn = {BookingStage.confirmed, BookingStage.inTrip, BookingStage.completed, BookingStage.settled};
    return confirmedOn.contains(b.stage) && range.contains(created(b));
  }).toList();

  final collected = payments.where((p) => range.contains(p.receivedOn)).fold<int>(
        0,
        (sum, p) => sum + (p.kind == PaymentKind.refund ? -p.amount : p.amount),
      );

  const owing = {BookingStage.confirmed, BookingStage.inTrip, BookingStage.completed};
  final outstanding = bookings.where((b) => owing.contains(b.stage) && b.balanceDue > 0).toList();
  final outstandingTotal = outstanding.fold<int>(0, (sum, b) => sum + b.balanceDue);

  var openDays = 0;
  var usedDays = 0;
  final live = bookings.where((b) => b.occupiesBus).toList();
  for (final bus in buses.where((b) => b.active)) {
    for (var d = range.start; d.isBefore(range.end); d = d.add(const Duration(days: 1))) {
      if (!availabilityFor(bus, d).available) continue;
      openDays++;
      final dayEnd = d.add(const Duration(days: 1));
      if (live.any((b) => b.busId == bus.id && b.start.isBefore(dayEnd) && b.end.isAfter(d))) usedDays++;
    }
  }

  final failed = searchMisses.where(range.contains).length;

  final waits = [
    for (final b in confirmedThisPeriod)
      if (b.confirmedAt != null && b.createdAt != null) b.confirmedAt!.difference(b.createdAt!).inMinutes,
  ];
  final avgWait = waits.isEmpty ? null : (waits.reduce((a, b) => a + b) / waits.length).round();

  final activeHolds = bookings.where((b) => b.isHold && b.holdSecondsLeft(now) > 0).length;

  final busVendor = {for (final b in buses) b.id: b.vendorId};
  final vendorStats = [
    for (final v in vendors)
      VendorStat(
        name: v.name,
        bookings: bookings.where((b) => busVendor[b.busId] == v.id && range.contains(created(b))).length,
      ),
  ]..sort((a, b) => b.bookings.compareTo(a.bookings));

  return Report(
    metrics: [
      ReportMetric(
        label: 'Requests',
        value: '$requests',
        sublabel: previousRequests == 0 && requests == 0
            ? null
            : '${delta >= 0 ? '+' : ''}$delta vs previous ${period == ReportPeriod.today ? 'day' : '${period.days} days'}',
      ),
      ReportMetric(label: 'Confirmed', value: '${confirmedThisPeriod.length}'),
      ReportMetric(label: 'Collected', value: AppMoneyFormat.rupees(collected), sublabel: 'net of refunds'),
      ReportMetric(
        label: 'Outstanding payments',
        value: AppMoneyFormat.rupees(outstandingTotal),
        sublabel: 'across ${outstanding.length} ${outstanding.length == 1 ? 'booking' : 'bookings'}',
      ),
      ReportMetric(
        label: 'Fleet utilisation',
        value: openDays == 0 ? '—' : '${(usedDays * 100 / openDays).round()}%',
        sublabel: period == ReportPeriod.today ? 'today' : 'last ${period.days} days',
      ),
      ReportMetric(label: 'Failed searches', value: '$failed', sublabel: 'no bus available'),
      ReportMetric(label: 'Avg. hold-to-confirm', value: avgWait == null ? '—' : '$avgWait min'),
      ReportMetric(label: 'Holds right now', value: '$activeHolds', sublabel: 'waiting for staff'),
    ],
    vendors: vendorStats,
  );
}
