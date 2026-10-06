import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/reports.dart';

final now = DateTime(2026, 10, 14, 12); // a Wednesday

const _open = DayAvailability(available: true, start: TimeOfDay(hour: 6, minute: 0), end: TimeOfDay(hour: 22, minute: 0));
const _closed = DayAvailability.closed();

BusRecord bus(String id, {String vendorId = 'v1', bool active = true, List<DayAvailability>? week}) => BusRecord(
      id: id,
      regNumber: id,
      vendorId: vendorId,
      vendorName: vendorId,
      capacity: 20,
      seatType: 'x',
      ac: true,
      baseCity: 'Thane',
      driverName: 'D',
      active: active,
      weeklyAvailability: week ?? List.filled(7, _open),
    );

Booking booking(
  String id, {
  String busId = 'b1',
  BookingStage stage = BookingStage.confirmed,
  DateTime? createdAt,
  DateTime? confirmedAt,
  DateTime? start,
  int fare = 10000,
  int paid = 2500,
  DateTime? holdExpiresAt,
}) {
  final s = start ?? DateTime(2026, 10, 14, 9);
  return Booking(
    id: id,
    reference: 'CB-$id',
    customerName: 'C',
    customerPhone: '',
    route: 'A → B',
    capacity: 20,
    busId: busId,
    busReg: busId,
    start: s,
    end: s.add(const Duration(hours: 6)),
    totalFare: fare,
    amountPaid: paid,
    stage: stage,
    createdAt: createdAt ?? DateTime(2026, 10, 14, 8),
    confirmedAt: confirmedAt,
    holdExpiresAt: holdExpiresAt,
  );
}

Payment pay(PaymentKind kind, int amount, DateTime on) => Payment(
      id: '${kind.name}$amount',
      bookingId: 'x',
      kind: kind,
      amount: amount,
      mode: 'UPI',
      reference: '',
      receivedOn: on,
      recordedBy: 'Admin',
    );

Report report(
  ReportPeriod period, {
  List<Booking> bookings = const [],
  List<Payment> payments = const [],
  List<BusRecord>? buses,
  List<DateTime> misses = const [],
}) =>
    buildReport(
      period: period,
      now: now,
      bookings: bookings,
      payments: payments,
      buses: buses ?? [bus('b1')],
      vendors: [const Vendor(id: 'v1', name: 'Neeta', contactPerson: '', phone: '', active: true), const Vendor(id: 'v2', name: 'Shivneri', contactPerson: '', phone: '', active: true)],
      searchMisses: misses,
    );

String value(Report r, String label) => r.metrics.firstWhere((m) => m.label == label).value;
String? sub(Report r, String label) => r.metrics.firstWhere((m) => m.label == label).sublabel;

void main() {
  test('with nothing yet, the figures are zero or a dash, never invented', () {
    final r = report(ReportPeriod.today);
    expect(value(r, 'Requests'), '0');
    expect(value(r, 'Confirmed'), '0');
    expect(value(r, 'Collected'), '₹0');
    expect(value(r, 'Outstanding payments'), '₹0');
    expect(value(r, 'Failed searches'), '0');
    expect(value(r, 'Avg. hold-to-confirm'), '—');
    expect(value(r, 'Holds right now'), '0');
  });

  test('requests count what was held in the period and compare with the one before', () {
    final r = report(ReportPeriod.today, bookings: [
      booking('a', createdAt: DateTime(2026, 10, 14, 9)),
      booking('b', createdAt: DateTime(2026, 10, 14, 10)),
      booking('c', createdAt: DateTime(2026, 10, 13, 15)), // yesterday
    ]);
    expect(value(r, 'Requests'), '2');
    expect(sub(r, 'Requests'), '+1 vs previous day');
  });

  test('week and month widen the window', () {
    final bookings = [
      booking('a', createdAt: DateTime(2026, 10, 14)),
      booking('b', createdAt: DateTime(2026, 10, 10)),
      booking('c', createdAt: DateTime(2026, 9, 20)),
      booking('d', createdAt: DateTime(2026, 8, 1)),
    ];
    expect(value(report(ReportPeriod.today, bookings: bookings), 'Requests'), '1');
    expect(value(report(ReportPeriod.week, bookings: bookings), 'Requests'), '2');
    expect(value(report(ReportPeriod.month, bookings: bookings), 'Requests'), '3');
  });

  test('money collected is advance plus balance less refunds, by the day it was received', () {
    final r = report(ReportPeriod.today, payments: [
      pay(PaymentKind.advance, 4500, DateTime(2026, 10, 14, 10)),
      pay(PaymentKind.balance, 13500, DateTime(2026, 10, 14, 18)),
      pay(PaymentKind.refund, 3000, DateTime(2026, 10, 14, 19)),
      pay(PaymentKind.advance, 99999, DateTime(2026, 10, 13)), // another day
    ]);
    expect(value(r, 'Collected'), '₹15,000');
  });

  test('outstanding counts only bookings that still owe: confirmed, running, finished-unsettled', () {
    final r = report(ReportPeriod.today, bookings: [
      booking('a', stage: BookingStage.confirmed, fare: 18000, paid: 4500), // owes 13,500
      booking('b', stage: BookingStage.completed, fare: 12000, paid: 3000), // owes 9,000
      booking('c', stage: BookingStage.settled, fare: 12000, paid: 12000),
      booking('d', stage: BookingStage.requested, fare: 0, paid: 0),
      booking('e', stage: BookingStage.cancelled, fare: 10000, paid: 0),
    ]);
    expect(value(r, 'Outstanding payments'), '₹22,500');
    expect(sub(r, 'Outstanding payments'), 'across 2 bookings');
  });

  test('hold-to-confirm averages the wait for bookings confirmed in the period', () {
    final r = report(ReportPeriod.today, bookings: [
      booking('a', createdAt: DateTime(2026, 10, 14, 9, 0), confirmedAt: DateTime(2026, 10, 14, 9, 10)),
      booking('b', createdAt: DateTime(2026, 10, 14, 9, 0), confirmedAt: DateTime(2026, 10, 14, 9, 20)),
    ]);
    expect(value(r, 'Avg. hold-to-confirm'), '15 min');
    expect(value(r, 'Confirmed'), '2');
  });

  test('utilisation is booked days over open days, ignoring closed days and inactive buses', () {
    // Wed 14 Oct. b1 is open every day; b2 is closed on Wednesdays; b3 is inactive.
    final week = [..._allOpen()];
    week[2] = _closed;
    final r = report(
      ReportPeriod.today,
      buses: [bus('b1'), bus('b2', week: week), bus('b3', active: false)],
      bookings: [booking('a', busId: 'b1')],
    );
    expect(value(r, 'Fleet utilisation'), '100%'); // b1 open and used; b2 not counted; b3 not counted

    final idle = report(ReportPeriod.today, buses: [bus('b1'), bus('b9')], bookings: [booking('a', busId: 'b1')]);
    expect(value(idle, 'Fleet utilisation'), '50%');
  });

  test('a cancelled or expired booking does not count as use', () {
    final r = report(ReportPeriod.today, bookings: [booking('a', stage: BookingStage.cancelled), booking('b', stage: BookingStage.expired)]);
    expect(value(r, 'Fleet utilisation'), '0%');
  });

  test('with no bus open for charter the utilisation is a dash, not a divide-by-zero', () {
    final r = report(ReportPeriod.today, buses: [bus('b1', week: List.filled(7, _closed))]);
    expect(value(r, 'Fleet utilisation'), '—');
  });

  test('failed searches are counted by the day', () {
    final r = report(ReportPeriod.today, misses: [DateTime(2026, 10, 14, 9), DateTime(2026, 10, 14, 11), DateTime(2026, 10, 12)]);
    expect(value(r, 'Failed searches'), '2');
    expect(value(report(ReportPeriod.week, misses: [DateTime(2026, 10, 14), DateTime(2026, 10, 12)]), 'Failed searches'), '2');
  });

  test('holds right now are only those still running', () {
    final r = report(ReportPeriod.today, bookings: [
      booking('a', stage: BookingStage.requested, holdExpiresAt: now.add(const Duration(minutes: 10))),
      booking('b', stage: BookingStage.requested, holdExpiresAt: now.subtract(const Duration(minutes: 1))),
    ]);
    expect(value(r, 'Holds right now'), '1');
  });

  test('vendor-wise bookings are bookings in the period per vendor, busiest first', () {
    final r = report(
      ReportPeriod.today,
      buses: [bus('b1', vendorId: 'v1'), bus('b2', vendorId: 'v2')],
      bookings: [booking('a', busId: 'b2'), booking('b', busId: 'b2'), booking('c', busId: 'b1')],
    );
    expect(r.vendors.map((v) => '${v.name}:${v.bookings}'), ['Shivneri:2', 'Neeta:1']);
  });
}

List<DayAvailability> _allOpen() => List.filled(7, _open);
