import 'package:flutter/material.dart' show TimeOfDay;

import 'mock_data.dart';
import 'models.dart';

/// Availability rules for the Phase 0 prototype. Pure functions over
/// [MockData] so the admin calendar and the customer search apply exactly
/// the same logic.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

/// The window the admin set for the weekday [day] falls on.
DayAvailability availabilityFor(BusRecord bus, DateTime day) =>
    bus.weeklyAvailability[day.weekday - 1];

List<Booking> bookingsFor(String busReg, DateTime day) {
  final from = dateOnly(day);
  final to = from.add(const Duration(days: 1));
  return MockData.bookings
      .where((b) => b.busReg == busReg && b.start.isBefore(to) && from.isBefore(b.end))
      .toList();
}

bool _overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) =>
    aStart.isBefore(bEnd) && bStart.isBefore(aEnd);

bool isBlackedOut(String busReg, DateTime start, DateTime end) => MockData.blackouts.any((b) =>
    b.busReg == busReg &&
    _overlaps(start, end, dateOnly(b.from), dateOnly(b.to).add(const Duration(days: 1))));

Iterable<DateTime> daysTouched(DateTime start, DateTime end) sync* {
  var day = dateOnly(start);
  final last = dateOnly(end);
  while (!day.isAfter(last)) {
    yield day;
    day = day.add(const Duration(days: 1));
  }
}

/// A bus is free when it is active, every day the charter touches is one
/// the admin marked available, the bus can depart at pickup and is back by
/// drop, no blackout covers the span, and nothing else is already booked.
///
/// On a multi-day charter the bus stays with the customer overnight, so the
/// window gates the departure and the return rather than the hours in
/// between.
bool isBusFree(BusRecord bus, DateTime start, DateTime end) {
  if (!bus.active) return false;

  for (final day in daysTouched(start, end)) {
    if (!availabilityFor(bus, day).available) return false;
  }

  final departure = availabilityFor(bus, start);
  if (minutesOf(TimeOfDay.fromDateTime(start)) < minutesOf(departure.start)) return false;

  final arrival = availabilityFor(bus, end);
  if (minutesOf(TimeOfDay.fromDateTime(end)) > minutesOf(arrival.end)) return false;

  if (isBlackedOut(bus.regNumber, start, end)) return false;

  return !MockData.bookings
      .any((b) => b.busReg == bus.regNumber && _overlaps(start, end, b.start, b.end));
}

/// Buses the customer can actually charter for what they asked for.
List<BusRecord> searchBuses(SearchCriteria criteria) => MockData.buses
    .where((bus) =>
        isBusFree(bus, criteria.startsAt, criteria.endsAt) &&
        (criteria.capacity == null || bus.capacity >= criteria.capacity!))
    .toList();
