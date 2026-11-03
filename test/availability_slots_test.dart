import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/core/widgets/app_buttons.dart';
import 'package:charter_booking_ui/data/availability.dart';
import 'package:charter_booking_ui/data/mock_data.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/firestore/firestore_codec.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/features/admin/screens/bus_form_screen.dart';

TimeOfDay at(int h, [int m = 0]) => TimeOfDay(hour: h, minute: m);

/// 3–5 PM and 9–10 PM, every day.
final twice = DayAvailability.withSlots(
  available: true,
  slots: [TimeSlot(start: at(15), end: at(17)), TimeSlot(start: at(21), end: at(22))],
);

BusRecord busWith(DayAvailability day) {
  final base = MockData.buses.first;
  return BusRecord(
    id: 'slots-bus',
    regNumber: 'MH-01-SL-0001',
    vendorId: base.vendorId,
    vendorName: base.vendorName,
    capacity: 20,
    seatType: base.seatType,
    ac: true,
    baseCity: base.baseCity,
    driverName: 'Unassigned',
    active: true,
    amenities: const [],
    weeklyAvailability: List.filled(7, day),
  );
}

bool free(BusRecord bus, DateTime start, DateTime end) =>
    isBusFree(bus, start, end, bookings: const [], blackouts: const []);

void main() {
  final bus = busWith(twice);
  final mon = DateTime(2026, 9, 14);

  group('the engine', () {
    test('a trip inside either slot is free', () {
      expect(free(bus, mon.add(const Duration(hours: 15, minutes: 30)), mon.add(const Duration(hours: 16, minutes: 30))), isTrue);
      expect(free(bus, mon.add(const Duration(hours: 21)), mon.add(const Duration(hours: 22))), isTrue);
    });

    test('a same-day trip cannot run across the gap between slots', () {
      expect(free(bus, mon.add(const Duration(hours: 16)), mon.add(const Duration(hours: 21, minutes: 30))), isFalse);
      expect(free(bus, mon.add(const Duration(hours: 18)), mon.add(const Duration(hours: 19))), isFalse);
      expect(free(bus, mon.add(const Duration(hours: 14)), mon.add(const Duration(hours: 16))), isFalse);
    });

    test('a multi-day trip leaves in one slot and returns in a slot on its last day', () {
      final out = mon.add(const Duration(hours: 21));
      expect(free(bus, out, mon.add(const Duration(days: 2, hours: 16))), isTrue);
      expect(free(bus, out, mon.add(const Duration(days: 2, hours: 19))), isFalse);
    });

    test('a closed day in between still blocks a multi-day trip', () {
      final week = [twice, const DayAvailability.closed(), twice, twice, twice, twice, twice];
      final b = BusRecord(
        id: 'x', regNumber: 'X', vendorId: '', vendorName: '', capacity: 10, seatType: '', ac: false,
        baseCity: '', driverName: '', active: true, amenities: const [], weeklyAvailability: week,
      );
      expect(free(b, mon.add(const Duration(hours: 15)), mon.add(const Duration(days: 2, hours: 16))), isFalse);
    });

    test('the departure slot is the one the pickup falls in', () {
      final slot = departureSlot(bus, mon.add(const Duration(hours: 21, minutes: 30)))!;
      expect(slot.start, at(21));
      expect(departureSlot(bus, mon.add(const Duration(hours: 18))), isNull);
    });
  });

  group('a day', () {
    test('sorts its slots and reports overlaps and backwards slots', () {
      final sorted = DayAvailability.withSlots(
          available: true, slots: [TimeSlot(start: at(21), end: at(22)), TimeSlot(start: at(9), end: at(10))]);
      expect(sorted.start, at(9));
      expect(sorted.problem, isNull);
      final overlap = DayAvailability.withSlots(
          available: true, slots: [TimeSlot(start: at(9), end: at(12)), TimeSlot(start: at(11), end: at(13))]);
      expect(overlap.problem, contains('overlap'));
      final back = DayAvailability.withSlots(available: true, slots: [TimeSlot(start: at(12), end: at(9))]);
      expect(back.problem, contains("'To' must be after 'From'"));
      expect(const DayAvailability.closed().problem, isNull);
    });

    test('slots that touch are fine', () {
      final d = DayAvailability.withSlots(
          available: true, slots: [TimeSlot(start: at(9), end: at(12)), TimeSlot(start: at(12), end: at(15))]);
      expect(d.problem, isNull);
    });
  });

  group('storage', () {
    test('slots survive a round trip, and the first slot is still written as start and end', () {
      final map = Codec.busToMap(bus);
      final day = (map['weeklyAvailability'] as List).first as Map;
      expect(day['start'], 15 * 60);
      expect(day['end'], 17 * 60);
      expect((day['slots'] as List), hasLength(2));
      final back = Codec.busFromMap('slots-bus', map);
      expect(back.weeklyAvailability.first.slots, twice.slots);
    });

    test('a day saved before slots existed reads as one slot', () {
      final map = Codec.busToMap(bus);
      final old = (map['weeklyAvailability'] as List)
          .map((d) => {'available': true, 'start': 360, 'end': 600})
          .toList();
      final back = Codec.busFromMap('slots-bus', {...map, 'weeklyAvailability': old});
      expect(back.weeklyAvailability.first.slots, [TimeSlot(start: at(6), end: at(10))]);
    });
  });

  group('the bus form', () {
    late MockBackend backend;

    Future<void> open(WidgetTester tester, BusRecord b) async {
      tester.view.physicalSize = const Size(1170, 6000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      backend = MockBackend();
      await tester.pumpWidget(ProviderScope(
        overrides: [mockBackendProvider.overrideWithValue(backend)],
        child: MaterialApp(theme: AppTheme.light, home: BusFormScreen(bus: b)),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Future<void> showFirst(WidgetTester tester, Finder f) async {
      await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
      await settle(tester);
    }

    testWidgets('a day with one slot offers Add a slot and no remove', (tester) async {
      await open(tester, busWith(const DayAvailability(available: true)));
      await showFirst(tester, find.text('Add a slot').first);
      expect(find.text('Add a slot'), findsWidgets);
      expect(find.byTooltip('Remove slot'), findsNothing);
    });

    testWidgets('a day with two slots shows both, each with a remove', (tester) async {
      await open(tester, busWith(twice));
      await showFirst(tester, find.byTooltip('Remove slot').first);
      expect(find.byTooltip('Remove slot'), findsWidgets);
      expect(find.text('03:00 PM'), findsWidgets);
      expect(find.text('09:00 PM'), findsWidgets);
    });

    testWidgets('adding a slot gives the day a second From and To, and it can be removed again', (tester) async {
      await open(tester, busWith(const DayAvailability(available: true)));
      await showFirst(tester, find.text('Add a slot').first);
      await tester.tap(find.text('Add a slot').first);
      await settle(tester);
      expect(find.byTooltip('Remove slot'), findsNWidgets(2));
      await tester.ensureVisible(find.byTooltip('Remove slot').first);
      await settle(tester);
      await tester.tap(find.byTooltip('Remove slot').first);
      await settle(tester);
      expect(find.byTooltip('Remove slot'), findsNothing);
    });

    testWidgets('a day stops offering Add a slot at four slots', (tester) async {
      final four = DayAvailability.withSlots(
          available: true, slots: [for (var h = 1; h <= 7; h += 2) TimeSlot(start: at(h), end: at(h + 1))]);
      await open(tester, busWith(four));
      await showFirst(tester, find.byTooltip('Remove slot').first);
      expect(find.byTooltip('Remove slot'), findsWidgets);
      expect(find.text('Add a slot'), findsNothing);
    });

    testWidgets('overlapping slots show the problem and keep Save disabled', (tester) async {
      final overlapping = DayAvailability(
          available: true, start: at(9), end: at(12), extraSlots: [TimeSlot(start: at(11), end: at(13))]);
      await open(tester, busWith(overlapping));
      await showFirst(tester, find.text('These slots overlap.').first);
      expect(find.text('These slots overlap.'), findsWidgets);
      await showFirst(tester, find.byType(PrimaryButton));
      expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNull);
    });

    testWidgets('saving a bus with two slots stores both', (tester) async {
      final b = busWith(twice);
      await open(tester, b);
      await tester.scrollUntilVisible(find.text('Save changes'), 300, scrollable: find.byType(Scrollable).first);
      await settle(tester);
      await tester.tap(find.text('Save changes'));
      await settle(tester);
      final saved = backend.buses.items.firstWhere((x) => x.id == 'slots-bus');
      expect(saved.weeklyAvailability.first.slots, twice.slots);
    });
  });
}
