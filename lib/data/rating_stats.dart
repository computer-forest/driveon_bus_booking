import 'models.dart';

/// Averages over a set of ratings (each score is 1 to 5).
class RatingStats {
  const RatingStats({required this.count, required this.bus, required this.driver, required this.overall});

  final int count;
  final double bus;
  final double driver;
  final double overall;

  static const empty = RatingStats(count: 0, bus: 0, driver: 0, overall: 0);
}

RatingStats ratingStats(Iterable<Rating> ratings) {
  final list = ratings.toList();
  if (list.isEmpty) return RatingStats.empty;
  double avg(int Function(Rating) pick) => list.map(pick).reduce((a, b) => a + b) / list.length;
  return RatingStats(count: list.length, bus: avg((r) => r.bus), driver: avg((r) => r.driver), overall: avg((r) => r.overall));
}

/// One bus's ratings, found through the booking each rating was left for.
class BusRatingStat {
  const BusRatingStat({required this.busReg, required this.stats});
  final String busReg;
  final RatingStats stats;
}

/// Ratings grouped by the bus that did the trip, lowest overall first so the
/// buses that need attention come to the top. A rating whose booking is gone
/// is left out of the grouping (it still counts in the overall figures).
List<BusRatingStat> ratingsByBus(Iterable<Rating> ratings, Iterable<Booking> bookings) {
  final regOf = {for (final b in bookings) b.id: b.busReg};
  final groups = <String, List<Rating>>{};
  for (final r in ratings) {
    final reg = regOf[r.bookingId];
    if (reg != null && reg.isNotEmpty) groups.putIfAbsent(reg, () => []).add(r);
  }
  return [for (final e in groups.entries) BusRatingStat(busReg: e.key, stats: ratingStats(e.value))]
    ..sort((a, b) => a.stats.overall.compareTo(b.stats.overall));
}
