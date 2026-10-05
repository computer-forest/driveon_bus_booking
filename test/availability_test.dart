import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/data/availability.dart';
import 'package:charter_booking_ui/data/mock_data.dart';
import 'package:charter_booking_ui/data/models.dart';

/// Seeded fleet these tests lean on (Mon 14 Sep 2026 is a Monday):
///   MH-04-BT-7781 — weekdays 2PM–10PM, closed weekends; booked
///                   3–8PM on Mon 14 and Wed 16 Sep; blacked out 20–22 Sep.
///   MH-04-CT-9902 — every day 6AM–5PM; booked 8AM–2PM Mon 14 and Tue 15 Sep.
///   MH-12-AK-1120 — Mon–Sat 6AM–11PM, closed Sunday; held 9AM–4PM Mon 14 Sep.
///   MH-14-DE-5567 — 40 seater, inactive.
SearchCriteria criteria(
  DateTime day,
  int fromHour,
  int toHour, {
  int? capacity,
}) =>
    SearchCriteria(
      pickup: const LocationEntry(city: 'Thane', area: 'Thane West'),
      drop: const LocationEntry(city: 'Pune', area: 'Hinjewadi'),
      pickupDate: day,
      pickupTime: TimeOfDay(hour: fromHour, minute: 0),
      dropDate: day,
      dropTime: TimeOfDay(hour: toHour, minute: 0),
      isRoundTrip: false,
      returnDate: day,
      returnTime: TimeOfDay(hour: toHour, minute: 0),
      capacity: capacity,
      summary: 'test',
    );

List<String> regsFor(
  SearchCriteria c, {
  Duration bufferBefore = Duration.zero,
  Duration bufferAfter = Duration.zero,
}) =>
    searchBuses(
      c,
      buses: MockData.buses,
      bookings: MockData.bookings,
      blackouts: MockData.blackouts,
      bufferBefore: bufferBefore,
      bufferAfter: bufferAfter,
    ).map((b) => b.regNumber).toList();

void main() {
  final monday = DateTime(2026, 9, 14);
  final wednesday = DateTime(2026, 9, 16);
  final saturday = DateTime(2026, 9, 19);
  final blackoutMonday = DateTime(2026, 9, 21);

  test('a charter starting before the window opens is excluded', () {
    expect(regsFor(criteria(monday, 6, 10)), isNot(contains('MH-04-BT-7781')));
  });

  test('a charter inside the window is offered', () {
    expect(regsFor(criteria(monday, 14, 15)), contains('MH-04-BT-7781'));
  });

  test('a charter running past the window close is excluded', () {
    expect(regsFor(criteria(monday, 15, 23)), isNot(contains('MH-04-BT-7781')));
  });

  test('a day the admin marked unavailable is excluded', () {
    expect(regsFor(criteria(saturday, 15, 20)), isNot(contains('MH-04-BT-7781')));
  });

  test('an overlapping booking excludes the bus', () {
    expect(regsFor(criteria(wednesday, 16, 18)), isNot(contains('MH-04-BT-7781')));
  });

  test('the same day outside the booking is still offered', () {
    expect(regsFor(criteria(wednesday, 14, 15)), contains('MH-04-BT-7781'));
  });

  test('a blackout excludes the bus', () {
    expect(regsFor(criteria(blackoutMonday, 15, 20)), isNot(contains('MH-04-BT-7781')));
  });

  test('inactive buses never appear', () {
    expect(regsFor(criteria(monday, 8, 12)), isNot(contains('MH-14-DE-5567')));
  });

  test('capacity filters to buses that seat at least the group', () {
    expect(regsFor(criteria(monday, 17, 20, capacity: 35)), ['MH-12-AK-1120']);
    expect(regsFor(criteria(monday, 17, 20, capacity: 40)), isEmpty);
  });

  test('a hold blocks the bus just like a confirmed booking', () {
    // MH-12-AK-1120 is held (not yet confirmed) 9AM–4PM on Monday.
    expect(regsFor(criteria(monday, 10, 14, capacity: 35)), isNot(contains('MH-12-AK-1120')));
    expect(regsFor(criteria(monday, 17, 20, capacity: 35)), contains('MH-12-AK-1120'));
  });

  test('a round trip is held across every day it touches', () {
    final overnight = SearchCriteria(
      pickup: const LocationEntry(city: 'Thane', area: 'Thane West'),
      drop: const LocationEntry(city: 'Pune', area: 'Hinjewadi'),
      pickupDate: saturday,
      pickupTime: const TimeOfDay(hour: 8, minute: 0),
      dropDate: saturday,
      dropTime: const TimeOfDay(hour: 20, minute: 0),
      isRoundTrip: true,
      returnDate: DateTime(2026, 9, 20),
      returnTime: const TimeOfDay(hour: 16, minute: 0),
      summary: 'test',
    );
    // MH-12-AK-1120 is open Saturday but closed Sunday, so the return leg
    // takes it out even though the departure fits.
    expect(regsFor(overnight), isNot(contains('MH-12-AK-1120')));
  });

  group('buffers', () {
    test('without a buffer, a trip can start the minute another ends', () {
      // MH-04-BT-7781 is booked 3–8PM on Monday; 8–10PM is free.
      expect(regsFor(criteria(monday, 20, 22)), contains('MH-04-BT-7781'));
    });

    test('a post-trip buffer rules out a start right after another trip', () {
      expect(
        regsFor(criteria(monday, 20, 22), bufferAfter: const Duration(minutes: 45)),
        isNot(contains('MH-04-BT-7781')),
      );
    });

    test('a pre-trip buffer rules out a trip ending right before another', () {
      expect(
        regsFor(criteria(monday, 14, 15), bufferBefore: const Duration(minutes: 90)),
        isNot(contains('MH-04-BT-7781')),
      );
    });

    test('a buffer does not touch a trip that is far enough away', () {
      expect(
        regsFor(criteria(monday, 21, 22), bufferAfter: const Duration(minutes: 45)),
        contains('MH-04-BT-7781'),
      );
    });
  });

  group('blackoutOn', () {
    test('finds the blackout covering a day, inclusive of both ends', () {
      for (final day in [DateTime(2026, 9, 20), DateTime(2026, 9, 21), DateTime(2026, 9, 22)]) {
        expect(blackoutOn('bus-7781', day, MockData.blackouts)?.id, 'blk-1');
      }
    });

    test('is null outside the span or for another bus', () {
      expect(blackoutOn('bus-7781', DateTime(2026, 9, 19), MockData.blackouts), isNull);
      expect(blackoutOn('bus-7781', DateTime(2026, 9, 23), MockData.blackouts), isNull);
      expect(blackoutOn('bus-9902', DateTime(2026, 9, 21), MockData.blackouts), isNull);
    });
  });
}
