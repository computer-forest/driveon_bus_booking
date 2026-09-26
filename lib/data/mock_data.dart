import 'package:flutter/material.dart' show TimeOfDay;

import 'models.dart';

const _afternoon = DayAvailability(
  available: true,
  start: TimeOfDay(hour: 14, minute: 0),
  end: TimeOfDay(hour: 22, minute: 0),
);
const _dayShift = DayAvailability(
  available: true,
  start: TimeOfDay(hour: 6, minute: 0),
  end: TimeOfDay(hour: 17, minute: 0),
);
const _longDay = DayAvailability(
  available: true,
  start: TimeOfDay(hour: 6, minute: 0),
  end: TimeOfDay(hour: 23, minute: 0),
);
const _closed = DayAvailability.closed();

/// In-memory store for the Phase 0 prototype. The fleet lists are mutable
/// so admin edits hold for the session; Phase 1 replaces all of this with
/// Firestore.
class MockData {
  MockData._();

  static const driver = DriverInfo(
    name: 'Suresh Patil',
    phone: '+91 90000 11122',
    busNumber: 'MH-04-BT-7781',
  );

  static const ledger = [
    LedgerEntry(label: 'Total fare', amount: '₹18,000'),
    LedgerEntry(label: 'Advance received', amount: '₹4,500', note: 'Recorded by Admin · 8 Sep'),
    LedgerEntry(label: 'Balance due', amount: '₹13,500'),
  ];

  static const locations = [
    LocationEntry(city: 'Thane', area: 'Thane West', saved: true),
    LocationEntry(city: 'Thane', area: 'Ghodbunder Road', saved: true),
    LocationEntry(city: 'Mumbai', area: 'Andheri East'),
    LocationEntry(city: 'Mumbai', area: 'Bandra West'),
    LocationEntry(city: 'Mumbai', area: 'Borivali'),
    LocationEntry(city: 'Navi Mumbai', area: 'Vashi'),
    LocationEntry(city: 'Pune', area: 'Hinjewadi'),
    LocationEntry(city: 'Mahabaleshwar', area: 'Main Market'),
    LocationEntry(city: 'Lonavala', area: 'Tungarli'),
    LocationEntry(city: 'Alibaug', area: 'Alibaug Bus Stand'),
  ];

  static const recentLocations = [
    LocationEntry(city: 'Thane', area: 'Thane West'),
    LocationEntry(city: 'Mahabaleshwar', area: 'Main Market'),
  ];

  static const vendors = [
    Vendor(name: 'Neeta Travels', contactPerson: 'Suresh Neeta', phone: '+91 98200 10001', busCount: 6, active: true),
    Vendor(name: 'Shivneri Coaches', contactPerson: 'Anil Bhosale', phone: '+91 98200 10002', busCount: 4, active: true),
    Vendor(name: 'Konkan Darshan', contactPerson: 'Meghna Rane', phone: '+91 98200 10003', busCount: 2, active: false),
  ];

  static final List<BusRecord> buses = [
    const BusRecord(
      regNumber: 'MH-04-BT-7781',
      vendorName: 'Neeta Travels',
      capacity: 20,
      seatType: 'Pushback seats',
      ac: true,
      baseCity: 'Thane',
      driverName: 'Suresh Patil',
      active: true,
      weeklyAvailability: [_afternoon, _afternoon, _afternoon, _afternoon, _afternoon, _closed, _closed],
      amenities: ['AC', 'Pushback seats', 'Reading lights', 'Charging points'],
    ),
    const BusRecord(
      regNumber: 'MH-04-CT-9902',
      vendorName: 'Neeta Travels',
      capacity: 17,
      seatType: 'Pushback seats',
      ac: true,
      baseCity: 'Thane',
      driverName: 'Ramesh Jadhav',
      active: true,
      weeklyAvailability: [_dayShift, _dayShift, _dayShift, _dayShift, _dayShift, _dayShift, _dayShift],
      amenities: ['AC', 'Pushback seats', 'Music system'],
    ),
    const BusRecord(
      regNumber: 'MH-12-AK-1120',
      vendorName: 'Shivneri Coaches',
      capacity: 35,
      seatType: 'Highback seats',
      ac: false,
      baseCity: 'Pune',
      driverName: 'Vikas More',
      active: true,
      weeklyAvailability: [_longDay, _longDay, _longDay, _longDay, _longDay, _longDay, _closed],
      amenities: ['Highback seats', 'Extra legroom'],
    ),
    const BusRecord(
      regNumber: 'MH-14-DE-5567',
      vendorName: 'Shivneri Coaches',
      capacity: 40,
      seatType: 'Pushback seats',
      ac: true,
      baseCity: 'Pune',
      driverName: 'Unassigned',
      active: false,
      weeklyAvailability: [_longDay, _longDay, _longDay, _longDay, _longDay, _longDay, _longDay],
      amenities: ['AC', 'Pushback seats', 'Luggage hold'],
    ),
  ];

  /// One record per charter, from hold through settlement. Seeded so
  /// Mon 14 Sep 2026 — the prototype's "today" — already shows a hold,
  /// a confirmed trip and one in progress, across three different buses.
  static final List<Booking> bookings = [
    Booking(
      reference: 'CB-20260914-0472',
      customerName: 'Rohan Deshmukh',
      customerPhone: '+91 98200 11223',
      route: 'Thane → Mahabaleshwar',
      capacity: 20,
      busReg: 'MH-04-BT-7781',
      start: DateTime(2026, 9, 14, 15, 0),
      end: DateTime(2026, 9, 14, 20, 0),
      totalFare: 18000,
      amountPaid: 4500,
      stage: BookingStage.confirmed,
    ),
    Booking(
      reference: 'CB-20260914-0473',
      customerName: 'Anita Kulkarni',
      customerPhone: '+91 98200 22334',
      route: 'Mumbai → Lonavala',
      capacity: 17,
      busReg: 'MH-04-CT-9902',
      start: DateTime(2026, 9, 14, 8, 0),
      end: DateTime(2026, 9, 14, 14, 0),
      totalFare: 12000,
      amountPaid: 3000,
      stage: BookingStage.inTrip,
    ),
    Booking(
      reference: 'CB-20260914-0474',
      customerName: 'Karan Mehta',
      customerPhone: '+91 98200 33445',
      route: 'Pune → Panchgani',
      capacity: 35,
      busReg: 'MH-12-AK-1120',
      start: DateTime(2026, 9, 14, 9, 0),
      end: DateTime(2026, 9, 14, 16, 0),
      totalFare: 0,
      amountPaid: 0,
      stage: BookingStage.requested,
      holdSecondsLeft: 252,
    ),
    Booking(
      reference: 'CB-20260915-0490',
      customerName: 'Deepak Joshi',
      customerPhone: '+91 98200 44556',
      route: 'Thane → Igatpuri',
      capacity: 17,
      busReg: 'MH-04-CT-9902',
      start: DateTime(2026, 9, 15, 8, 0),
      end: DateTime(2026, 9, 15, 14, 0),
      totalFare: 10000,
      amountPaid: 2500,
      stage: BookingStage.confirmed,
    ),
    Booking(
      reference: 'CB-20260916-0491',
      customerName: 'Neha Sawant',
      customerPhone: '+91 98200 55667',
      route: 'Thane → Nashik',
      capacity: 20,
      busReg: 'MH-04-BT-7781',
      start: DateTime(2026, 9, 16, 15, 0),
      end: DateTime(2026, 9, 16, 20, 0),
      totalFare: 18000,
      amountPaid: 4500,
      stage: BookingStage.confirmed,
    ),
    Booking(
      reference: 'CB-20260917-0492',
      customerName: 'Sanjana Pillai',
      customerPhone: '+91 98200 66778',
      route: 'Pune → Mahabaleshwar',
      capacity: 35,
      busReg: 'MH-12-AK-1120',
      start: DateTime(2026, 9, 17, 7, 0),
      end: DateTime(2026, 9, 17, 18, 0),
      totalFare: 24000,
      amountPaid: 6000,
      stage: BookingStage.confirmed,
    ),
    Booking(
      reference: 'CB-20260915-0480',
      customerName: 'Prakash Iyer',
      customerPhone: '+91 98200 77889',
      route: 'Navi Mumbai → Karjat',
      capacity: 17,
      busReg: 'MH-04-CT-9902',
      start: DateTime(2026, 9, 20, 8, 0),
      end: DateTime(2026, 9, 20, 13, 0),
      totalFare: 0,
      amountPaid: 0,
      stage: BookingStage.requested,
      holdSecondsLeft: 1323,
    ),
    Booking(
      reference: 'CB-20260915-0481',
      customerName: 'Meera Shah',
      customerPhone: '+91 98200 88990',
      route: 'Thane → Alibaug',
      capacity: 35,
      busReg: 'MH-12-AK-1120',
      start: DateTime(2026, 9, 21, 8, 0),
      end: DateTime(2026, 9, 21, 16, 0),
      totalFare: 0,
      amountPaid: 0,
      stage: BookingStage.requested,
      holdSecondsLeft: 1661,
    ),
  ];

  static final List<DriverRecord> drivers = [
    const DriverRecord(
      name: 'Suresh Patil',
      phone: '+91 90000 11122',
      licenceNumber: 'MH04 20180012345',
      vendorName: 'Neeta Travels',
    ),
    const DriverRecord(
      name: 'Ramesh Jadhav',
      phone: '+91 90000 22233',
      licenceNumber: 'MH04 20170034567',
      vendorName: 'Neeta Travels',
    ),
    const DriverRecord(
      name: 'Vikas More',
      phone: '+91 90000 33344',
      licenceNumber: 'MH12 20190056789',
      vendorName: 'Shivneri Coaches',
    ),
    const DriverRecord(
      name: 'Pramod Kale',
      phone: '+91 90000 44455',
      licenceNumber: 'MH12 20200078901',
      vendorName: 'Shivneri Coaches',
    ),
  ];

  static const notifications = [
    AppNotification(
      title: 'Booking confirmed',
      body: 'CB-20260914-0472 is confirmed — Suresh Patil will drive your bus.',
      time: '2 min ago',
      read: false,
      tone: NotificationTone.success,
    ),
    AppNotification(
      title: 'Hold expiring soon',
      body: 'Your held bus for Thane → Mahabaleshwar releases in 5 minutes.',
      time: '18 min ago',
      read: false,
      tone: NotificationTone.urgent,
    ),
    AppNotification(
      title: 'Payment recorded',
      body: '₹4,500 advance recorded by Admin for CB-20260914-0472.',
      time: '1 hr ago',
      read: true,
      tone: NotificationTone.info,
    ),
    AppNotification(
      title: 'Cost confirmed',
      body: 'Total fare for your Mumbai → Alibaug trip is ₹22,000.',
      time: 'Yesterday',
      read: true,
      tone: NotificationTone.info,
    ),
  ];

  static const faqs = [
    FaqItem(
      question: 'How is the whole bus booked, not just seats?',
      answer:
          'You hire the entire vehicle for your window — there is no seat map. Once you select a bus it is held for you immediately.',
    ),
    FaqItem(
      question: 'How do I pay?',
      answer:
          'There is no payment gateway. Our team calls to confirm the cost, and the advance or full amount is paid directly — Admin records it against your booking.',
    ),
    FaqItem(
      question: 'Can I cancel a booking?',
      answer: 'Request cancellation from My Bookings. Our team processes it and records any refund.',
    ),
    FaqItem(
      question: 'What if my held bus expires?',
      answer: 'A hold lasts a fixed window. If it lapses before confirmation, the bus is released and you can search again.',
    ),
  ];

  static const reportMetrics = [
    ReportMetric(label: 'Requests today', value: '18', sublabel: '+4 vs yesterday'),
    ReportMetric(label: 'Confirmed today', value: '11'),
    ReportMetric(label: 'Outstanding payments', value: '₹86,200', sublabel: 'across 9 bookings'),
    ReportMetric(label: 'Fleet utilisation', value: '62%', sublabel: 'this week'),
    ReportMetric(label: 'Failed searches', value: '5', sublabel: 'no bus available'),
    ReportMetric(label: 'Avg. hold-to-confirm', value: '14 min'),
  ];

  static const auditLog = [
    AuditEntry(
      actor: 'Admin · Priya',
      action: 'Recorded advance payment',
      detail: 'CB-20260914-0472 · ₹4,500 via UPI',
      time: 'Today, 10:42 AM',
    ),
    AuditEntry(
      actor: 'Admin · Priya',
      action: 'Reallocated bus',
      detail: 'CB-20260914-0471 · MH-04-BT-7781 → MH-04-CT-9902',
      time: 'Today, 09:15 AM',
    ),
    AuditEntry(
      actor: 'Admin · Rohit',
      action: 'Cancelled booking',
      detail: 'CB-20260910-0460 · reason: customer requested',
      time: 'Yesterday, 6:02 PM',
    ),
    AuditEntry(
      actor: 'System',
      action: 'Hold expired',
      detail: 'CB-20260910-0458 · released after 30 min',
      time: 'Yesterday, 3:40 PM',
    ),
  ];

  static const templates = [
    MessageTemplate(
      name: 'Booking confirmed',
      channel: 'Push + Email',
      trigger: 'On advance/full payment recorded',
      preview: 'Your bus is confirmed! MH-04-BT-7781, driver Suresh Patil...',
    ),
    MessageTemplate(
      name: 'Cost confirmed',
      channel: 'Push',
      trigger: 'On Admin recording confirmed cost',
      preview: 'Total fare for your trip is ₹18,000. Advance due: ₹4,500.',
    ),
    MessageTemplate(
      name: 'Bus reallocated',
      channel: 'Push + Email',
      trigger: 'On Admin reallocation',
      preview: 'Your bus has changed to MH-04-CT-9902. New driver...',
    ),
    MessageTemplate(
      name: 'Hold about to expire',
      channel: 'Push (Admin)',
      trigger: '5 minutes before hold expiry',
      preview: 'CB-20260914-0472 hold expires in 5 minutes.',
    ),
  ];

  static final List<BlackoutEntry> blackouts = [
    BlackoutEntry(
      busReg: 'MH-04-BT-7781',
      reason: 'Annual service',
      from: DateTime(2026, 9, 20),
      to: DateTime(2026, 9, 22),
      isMaintenance: true,
    ),
    BlackoutEntry(
      busReg: 'MH-12-AK-1120',
      reason: 'Vendor-side festival block',
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 3),
    ),
  ];
}
