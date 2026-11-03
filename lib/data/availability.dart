import 'package:flutter/material.dart' show TimeOfDay;

import 'models.dart';

/// Availability rules. Pure functions over the lists they are handed, so the
/// customer search, the admin calendar and reallocation all apply exactly the
/// same logic, and the same rules can be ported to the server unchanged.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

/// The slots the admin set for the weekday [day] falls on.
DayAvailability availabilityFor(BusRecord bus, DateTime day) =>
    bus.weeklyAvailability[day.weekday - 1];

/// The slot a trip starting at [start] departs in, for showing customers the
/// hours that apply to them. Null when the bus is not available then.
TimeSlot? departureSlot(BusRecord bus, DateTime start) =>
    availabilityFor(bus, start).slotContaining(minutesOf(TimeOfDay.fromDateTime(start)));

bool _overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) =>
    aStart.isBefore(bEnd) && bStart.isBefore(aEnd);

/// Bookings that touch any part of [day] for one bus, earliest first.
List<Booking> bookingsFor(String busId, DateTime day, Iterable<Booking> bookings) {
  final from = dateOnly(day);
  final to = from.add(const Duration(days: 1));
  return bookings
      .where((b) => b.occupiesBus && b.busId == busId && b.start.isBefore(to) && from.isBefore(b.end))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));
}

/// Blackouts are whole days, inclusive of both ends.
bool isBlackedOut(String busId, DateTime start, DateTime end, Iterable<BlackoutEntry> blackouts) =>
    blackouts.any((b) =>
        b.busId == busId &&
        _overlaps(start, end, dateOnly(b.from), dateOnly(b.to).add(const Duration(days: 1))));

/// The blackout covering [day] for one bus, if any.
BlackoutEntry? blackoutOn(String busId, DateTime day, Iterable<BlackoutEntry> blackouts) {
  final from = dateOnly(day);
  final to = from.add(const Duration(days: 1));
  for (final b in blackouts) {
    if (b.busId == busId &&
        _overlaps(from, to, dateOnly(b.from), dateOnly(b.to).add(const Duration(days: 1)))) {
      return b;
    }
  }
  return null;
}

Iterable<DateTime> daysTouched(DateTime start, DateTime end) sync* {
  var day = dateOnly(start);
  final last = dateOnly(end);
  while (!day.isAfter(last)) {
    yield day;
    day = day.add(const Duration(days: 1));
  }
}

/// A bus is free when it is active, every day the charter touches is one
/// the admin marked available, pickup falls inside one of that day's slots,
/// drop falls inside a slot too (the same slot, for a same-day trip), no
/// blackout covers the span, and nothing else is already booked.
///
/// On a multi-day charter the bus stays with the customer overnight, so the
/// window gates the departure and the return rather than the hours in
/// between. A round trip is one continuous booking from outward pickup to
/// return drop, so checking [start]..[end] already covers the idle days.
///
/// [bufferBefore] and [bufferAfter] widen every existing booking, so a bus
/// is not offered too close to another trip. Both default to zero: the client
/// decided buffers do not block a bus, and staff check each booking by hand.
bool isBusFree(
  BusRecord bus,
  DateTime start,
  DateTime end, {
  required Iterable<Booking> bookings,
  required Iterable<BlackoutEntry> blackouts,
  Duration bufferBefore = Duration.zero,
  Duration bufferAfter = Duration.zero,
}) {
  if (!bus.active) return false;

  for (final day in daysTouched(start, end)) {
    if (!availabilityFor(bus, day).available) return false;
  }

  final departure = departureSlot(bus, start);
  if (departure == null) return false;
  final arrivalMinutes = minutesOf(TimeOfDay.fromDateTime(end));
  if (dateOnly(start) == dateOnly(end)) {
    // A same-day trip must fit in one slot: the gap between slots is not
    // bookable.
    if (!departure.contains(arrivalMinutes)) return false;
  } else if (availabilityFor(bus, end).slotContaining(arrivalMinutes) == null) {
    return false;
  }

  if (isBlackedOut(bus.id, start, end, blackouts)) return false;

  return !bookings.any((b) =>
      b.occupiesBus &&
      b.busId == bus.id &&
      _overlaps(start, end, b.start.subtract(bufferBefore), b.end.add(bufferAfter)));
}

/// Buses the customer can actually charter for what they asked for.
List<BusRecord> searchBuses(
  SearchCriteria criteria, {
  required Iterable<BusRecord> buses,
  required Iterable<Booking> bookings,
  required Iterable<BlackoutEntry> blackouts,
  Duration bufferBefore = Duration.zero,
  Duration bufferAfter = Duration.zero,
}) =>
    buses
        .where((bus) =>
            isBusFree(
              bus,
              criteria.startsAt,
              criteria.endsAt,
              bookings: bookings,
              blackouts: blackouts,
              bufferBefore: bufferBefore,
              bufferAfter: bufferAfter,
            ) &&
            (criteria.capacity == null || bus.capacity >= criteria.capacity!))
        .toList();
