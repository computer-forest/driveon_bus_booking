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

/// Seed data for the in-memory backend. Only the mock repositories read
/// this; screens go through providers. Phase 1 replaces the mock
/// repositories with Firestore-backed ones and this file with a one-off
/// import of the client's real master data.
class MockData {
  MockData._();

  /// The prototype's "today": every date below is seeded around it, and the
  /// app's clock is pinned to it until real data replaces the seeds.
  static final DateTime now = DateTime(2026, 9, 14, 10, 45);

  /// Fixed-rate outstation packages. The client supplied real rates for
  /// Mumbai + 17–20 seater Tempo traveller only; every other combination
  /// below is PLACEHOLDER sample data scaled off that chart, and is flagged
  /// with `sampleRates: true` so the UI labels it rather than passing it
  /// off as quotable pricing.
  static const packageLocations = [
    PackageLocation(
      city: 'Mumbai',
      packages: [
        SeaterPackage(
          seater: '17–20 seater Tempo traveller',
          trips: [
            PackageTrip(destination: 'Karjat', oneDayRate: 10500, twoDayRate: 16000),
            PackageTrip(destination: 'Neral / Matheran', oneDayRate: 10500, twoDayRate: 16500),
            PackageTrip(destination: 'Virar', oneDayRate: 10500, twoDayRate: 16500),
            PackageTrip(destination: 'Uran', oneDayRate: 10500, twoDayRate: 16500),
            PackageTrip(destination: 'Lonavala', oneDayRate: 13000, twoDayRate: 20000),
            PackageTrip(destination: 'Mahabaleshwar', oneDayRate: 15000, twoDayRate: 23000),
          ],
        ),
        SeaterPackage(
          seater: '22 seater Bus',
          sampleRates: true,
          trips: [
            PackageTrip(destination: 'Karjat', oneDayRate: 12000, twoDayRate: 18500),
            PackageTrip(destination: 'Neral / Matheran', oneDayRate: 12000, twoDayRate: 19000),
            PackageTrip(destination: 'Virar', oneDayRate: 12000, twoDayRate: 19000),
            PackageTrip(destination: 'Uran', oneDayRate: 12000, twoDayRate: 19000),
            PackageTrip(destination: 'Lonavala', oneDayRate: 15000, twoDayRate: 23000),
            PackageTrip(destination: 'Mahabaleshwar', oneDayRate: 17000, twoDayRate: 26500),
          ],
        ),
        SeaterPackage(
          seater: '27–30 seater Bus',
          sampleRates: true,
          trips: [
            PackageTrip(destination: 'Karjat', oneDayRate: 14000, twoDayRate: 21500),
            PackageTrip(destination: 'Neral / Matheran', oneDayRate: 14000, twoDayRate: 22500),
            PackageTrip(destination: 'Virar', oneDayRate: 14000, twoDayRate: 22500),
            PackageTrip(destination: 'Uran', oneDayRate: 14000, twoDayRate: 22500),
            PackageTrip(destination: 'Lonavala', oneDayRate: 17500, twoDayRate: 27000),
            PackageTrip(destination: 'Mahabaleshwar', oneDayRate: 20000, twoDayRate: 31000),
          ],
        ),
        SeaterPackage(
          seater: '35–40 seater Bus',
          sampleRates: true,
          trips: [
            PackageTrip(destination: 'Karjat', oneDayRate: 17000, twoDayRate: 25500),
            PackageTrip(destination: 'Neral / Matheran', oneDayRate: 17000, twoDayRate: 26500),
            PackageTrip(destination: 'Virar', oneDayRate: 17000, twoDayRate: 26500),
            PackageTrip(destination: 'Uran', oneDayRate: 17000, twoDayRate: 26500),
            PackageTrip(destination: 'Lonavala', oneDayRate: 21000, twoDayRate: 32000),
            PackageTrip(destination: 'Mahabaleshwar', oneDayRate: 24000, twoDayRate: 37000),
          ],
        ),
      ],
    ),
    PackageLocation(
      city: 'Navi Mumbai',
      packages: [
        SeaterPackage(
          seater: '17–20 seater Tempo traveller',
          sampleRates: true,
          trips: [
            PackageTrip(destination: 'Karjat', oneDayRate: 10000, twoDayRate: 15500),
            PackageTrip(destination: 'Neral / Matheran', oneDayRate: 10000, twoDayRate: 16000),
            PackageTrip(destination: 'Virar', oneDayRate: 10000, twoDayRate: 16000),
            PackageTrip(destination: 'Uran', oneDayRate: 10000, twoDayRate: 16000),
            PackageTrip(destination: 'Lonavala', oneDayRate: 12500, twoDayRate: 19500),
            PackageTrip(destination: 'Mahabaleshwar', oneDayRate: 14500, twoDayRate: 22500),
          ],
        ),
        SeaterPackage(
          seater: '22 seater Bus',
          sampleRates: true,
          trips: [
            PackageTrip(destination: 'Karjat', oneDayRate: 11500, twoDayRate: 18000),
            PackageTrip(destination: 'Neral / Matheran', oneDayRate: 11500, twoDayRate: 18500),
            PackageTrip(destination: 'Virar', oneDayRate: 11500, twoDayRate: 18500),
            PackageTrip(destination: 'Uran', oneDayRate: 11500, twoDayRate: 18500),
            PackageTrip(destination: 'Lonavala', oneDayRate: 14500, twoDayRate: 22500),
            PackageTrip(destination: 'Mahabaleshwar', oneDayRate: 16500, twoDayRate: 25500),
          ],
        ),
        SeaterPackage(
          seater: '27–30 seater Bus',
          sampleRates: true,
          trips: [
            PackageTrip(destination: 'Karjat', oneDayRate: 13500, twoDayRate: 21000),
            PackageTrip(destination: 'Neral / Matheran', oneDayRate: 13500, twoDayRate: 21500),
            PackageTrip(destination: 'Virar', oneDayRate: 13500, twoDayRate: 21500),
            PackageTrip(destination: 'Uran', oneDayRate: 13500, twoDayRate: 21500),
            PackageTrip(destination: 'Lonavala', oneDayRate: 17000, twoDayRate: 26000),
            PackageTrip(destination: 'Mahabaleshwar', oneDayRate: 19500, twoDayRate: 30000),
          ],
        ),
        SeaterPackage(
          seater: '35–40 seater Bus',
          sampleRates: true,
          trips: [
            PackageTrip(destination: 'Karjat', oneDayRate: 16500, twoDayRate: 25000),
            PackageTrip(destination: 'Neral / Matheran', oneDayRate: 16500, twoDayRate: 25500),
            PackageTrip(destination: 'Virar', oneDayRate: 16500, twoDayRate: 25500),
            PackageTrip(destination: 'Uran', oneDayRate: 16500, twoDayRate: 25500),
            PackageTrip(destination: 'Lonavala', oneDayRate: 20000, twoDayRate: 31000),
            PackageTrip(destination: 'Mahabaleshwar', oneDayRate: 23500, twoDayRate: 35500),
          ],
        ),
      ],
    ),
    PackageLocation(
      city: 'Thane',
      packages: [
        SeaterPackage(
          seater: '17–20 seater Tempo traveller',
          sampleRates: true,
          trips: [
            PackageTrip(destination: 'Karjat', oneDayRate: 10000, twoDayRate: 15000),
            PackageTrip(destination: 'Neral / Matheran', oneDayRate: 10000, twoDayRate: 15500),
            PackageTrip(destination: 'Virar', oneDayRate: 10000, twoDayRate: 15500),
            PackageTrip(destination: 'Uran', oneDayRate: 10000, twoDayRate: 15500),
            PackageTrip(destination: 'Lonavala', oneDayRate: 12500, twoDayRate: 19000),
            PackageTrip(destination: 'Mahabaleshwar', oneDayRate: 14000, twoDayRate: 22000),
          ],
        ),
        SeaterPackage(
          seater: '22 seater Bus',
          sampleRates: true,
          trips: [
            PackageTrip(destination: 'Karjat', oneDayRate: 11500, twoDayRate: 17500),
            PackageTrip(destination: 'Neral / Matheran', oneDayRate: 11500, twoDayRate: 18000),
            PackageTrip(destination: 'Virar', oneDayRate: 11500, twoDayRate: 18000),
            PackageTrip(destination: 'Uran', oneDayRate: 11500, twoDayRate: 18000),
            PackageTrip(destination: 'Lonavala', oneDayRate: 14000, twoDayRate: 22000),
            PackageTrip(destination: 'Mahabaleshwar', oneDayRate: 16500, twoDayRate: 25000),
          ],
        ),
        SeaterPackage(
          seater: '27–30 seater Bus',
          sampleRates: true,
          trips: [
            PackageTrip(destination: 'Karjat', oneDayRate: 13500, twoDayRate: 20500),
            PackageTrip(destination: 'Neral / Matheran', oneDayRate: 13500, twoDayRate: 21000),
            PackageTrip(destination: 'Virar', oneDayRate: 13500, twoDayRate: 21000),
            PackageTrip(destination: 'Uran', oneDayRate: 13500, twoDayRate: 21000),
            PackageTrip(destination: 'Lonavala', oneDayRate: 16500, twoDayRate: 25500),
            PackageTrip(destination: 'Mahabaleshwar', oneDayRate: 19000, twoDayRate: 29500),
          ],
        ),
        SeaterPackage(
          seater: '35–40 seater Bus',
          sampleRates: true,
          trips: [
            PackageTrip(destination: 'Karjat', oneDayRate: 16000, twoDayRate: 24500),
            PackageTrip(destination: 'Neral / Matheran', oneDayRate: 16000, twoDayRate: 25000),
            PackageTrip(destination: 'Virar', oneDayRate: 16000, twoDayRate: 25000),
            PackageTrip(destination: 'Uran', oneDayRate: 16000, twoDayRate: 25000),
            PackageTrip(destination: 'Lonavala', oneDayRate: 20000, twoDayRate: 30500),
            PackageTrip(destination: 'Mahabaleshwar', oneDayRate: 23000, twoDayRate: 35000),
          ],
        ),
      ],
    ),
  ];

  static const locations = [
    LocationEntry(id: 'loc-thane-west', city: 'Thane', area: 'Thane West', saved: true),
    LocationEntry(id: 'loc-ghodbunder', city: 'Thane', area: 'Ghodbunder Road', saved: true),
    LocationEntry(id: 'loc-andheri-e', city: 'Mumbai', area: 'Andheri East'),
    LocationEntry(id: 'loc-bandra-w', city: 'Mumbai', area: 'Bandra West'),
    LocationEntry(id: 'loc-borivali', city: 'Mumbai', area: 'Borivali'),
    LocationEntry(id: 'loc-vashi', city: 'Navi Mumbai', area: 'Vashi'),
    LocationEntry(id: 'loc-hinjewadi', city: 'Pune', area: 'Hinjewadi'),
    LocationEntry(id: 'loc-mahabaleshwar', city: 'Mahabaleshwar', area: 'Main Market'),
    LocationEntry(id: 'loc-lonavala', city: 'Lonavala', area: 'Tungarli'),
    LocationEntry(id: 'loc-alibaug', city: 'Alibaug', area: 'Alibaug Bus Stand'),
  ];

  /// Ids of the locations this customer searched most recently.
  static const recentLocationIds = ['loc-thane-west', 'loc-mahabaleshwar'];

  static const vendors = [
    Vendor(id: 'ven-neeta', name: 'Neeta Travels', contactPerson: 'Suresh Neeta', phone: '+91 98200 10001', active: true),
    Vendor(id: 'ven-shivneri', name: 'Shivneri Coaches', contactPerson: 'Anil Bhosale', phone: '+91 98200 10002', active: true),
    Vendor(id: 'ven-konkan', name: 'Konkan Darshan', contactPerson: 'Meghna Rane', phone: '+91 98200 10003', active: false),
  ];

  static const drivers = [
    DriverRecord(
      id: 'drv-suresh',
      name: 'Suresh Patil',
      phone: '+91 90000 11122',
      licenceNumber: 'MH04 20180012345',
      vendorId: 'ven-neeta',
      vendorName: 'Neeta Travels',
    ),
    DriverRecord(
      id: 'drv-ramesh',
      name: 'Ramesh Jadhav',
      phone: '+91 90000 22233',
      licenceNumber: 'MH04 20170034567',
      vendorId: 'ven-neeta',
      vendorName: 'Neeta Travels',
    ),
    DriverRecord(
      id: 'drv-vikas',
      name: 'Vikas More',
      phone: '+91 90000 33344',
      licenceNumber: 'MH12 20190056789',
      vendorId: 'ven-shivneri',
      vendorName: 'Shivneri Coaches',
    ),
    DriverRecord(
      id: 'drv-pramod',
      name: 'Pramod Kale',
      phone: '+91 90000 44455',
      licenceNumber: 'MH12 20200078901',
      vendorId: 'ven-shivneri',
      vendorName: 'Shivneri Coaches',
    ),
  ];

  static const buses = [
    BusRecord(
      id: 'bus-7781',
      regNumber: 'MH-04-BT-7781',
      vendorId: 'ven-neeta',
      vendorName: 'Neeta Travels',
      capacity: 20,
      seatType: 'Pushback seats',
      ac: true,
      baseCity: 'Thane',
      driverId: 'drv-suresh',
      driverName: 'Suresh Patil',
      active: true,
      weeklyAvailability: [_afternoon, _afternoon, _afternoon, _afternoon, _afternoon, _closed, _closed],
      amenities: ['AC', 'Pushback seats', 'Reading lights', 'Charging points'],
    ),
    BusRecord(
      id: 'bus-9902',
      regNumber: 'MH-04-CT-9902',
      vendorId: 'ven-neeta',
      vendorName: 'Neeta Travels',
      capacity: 17,
      seatType: 'Pushback seats',
      ac: true,
      baseCity: 'Thane',
      driverId: 'drv-ramesh',
      driverName: 'Ramesh Jadhav',
      active: true,
      weeklyAvailability: [_dayShift, _dayShift, _dayShift, _dayShift, _dayShift, _dayShift, _dayShift],
      amenities: ['AC', 'Pushback seats', 'Music system'],
    ),
    BusRecord(
      id: 'bus-1120',
      regNumber: 'MH-12-AK-1120',
      vendorId: 'ven-shivneri',
      vendorName: 'Shivneri Coaches',
      capacity: 35,
      seatType: 'Highback seats',
      ac: false,
      baseCity: 'Pune',
      driverId: 'drv-vikas',
      driverName: 'Vikas More',
      active: true,
      weeklyAvailability: [_longDay, _longDay, _longDay, _longDay, _longDay, _longDay, _closed],
      amenities: ['Highback seats', 'Extra legroom'],
    ),
    BusRecord(
      id: 'bus-5567',
      regNumber: 'MH-14-DE-5567',
      vendorId: 'ven-shivneri',
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
  /// Mon 14 Sep 2026 already shows a hold, a confirmed trip and one in
  /// progress, across three different buses.
  static final List<Booking> bookings = [
    Booking(
      id: 'bk-0472',
      reference: 'CB-20260914-0472',
      customerId: 'cust_919820011223',
      customerName: 'Rohan Deshmukh',
      customerPhone: '+91 98200 11223',
      route: 'Thane → Mahabaleshwar',
      capacity: 20,
      busId: 'bus-7781',
      busReg: 'MH-04-BT-7781',
      start: DateTime(2026, 9, 14, 15, 0),
      end: DateTime(2026, 9, 14, 20, 0),
      totalFare: 18000,
      amountPaid: 4500,
      stage: BookingStage.confirmed,
    ),
    Booking(
      id: 'bk-0473',
      reference: 'CB-20260914-0473',
      customerName: 'Anita Kulkarni',
      customerPhone: '+91 98200 22334',
      route: 'Mumbai → Lonavala',
      capacity: 17,
      busId: 'bus-9902',
      busReg: 'MH-04-CT-9902',
      start: DateTime(2026, 9, 14, 8, 0),
      end: DateTime(2026, 9, 14, 14, 0),
      totalFare: 12000,
      amountPaid: 3000,
      stage: BookingStage.inTrip,
    ),
    Booking(
      id: 'bk-0474',
      reference: 'CB-20260914-0474',
      customerName: 'Karan Mehta',
      customerPhone: '+91 98200 33445',
      route: 'Pune → Panchgani',
      capacity: 35,
      busId: 'bus-1120',
      busReg: 'MH-12-AK-1120',
      start: DateTime(2026, 9, 14, 9, 0),
      end: DateTime(2026, 9, 14, 16, 0),
      totalFare: 0,
      amountPaid: 0,
      stage: BookingStage.requested,
      holdExpiresAt: now.add(const Duration(seconds: 252)),
    ),
    Booking(
      id: 'bk-0490',
      reference: 'CB-20260915-0490',
      customerName: 'Deepak Joshi',
      customerPhone: '+91 98200 44556',
      route: 'Thane → Igatpuri',
      capacity: 17,
      busId: 'bus-9902',
      busReg: 'MH-04-CT-9902',
      start: DateTime(2026, 9, 15, 8, 0),
      end: DateTime(2026, 9, 15, 14, 0),
      totalFare: 10000,
      amountPaid: 2500,
      stage: BookingStage.confirmed,
    ),
    Booking(
      id: 'bk-0491',
      reference: 'CB-20260916-0491',
      customerName: 'Neha Sawant',
      customerPhone: '+91 98200 55667',
      route: 'Thane → Nashik',
      capacity: 20,
      busId: 'bus-7781',
      busReg: 'MH-04-BT-7781',
      start: DateTime(2026, 9, 16, 15, 0),
      end: DateTime(2026, 9, 16, 20, 0),
      totalFare: 18000,
      amountPaid: 4500,
      stage: BookingStage.confirmed,
    ),
    Booking(
      id: 'bk-0492',
      reference: 'CB-20260917-0492',
      customerName: 'Sanjana Pillai',
      customerPhone: '+91 98200 66778',
      route: 'Pune → Mahabaleshwar',
      capacity: 35,
      busId: 'bus-1120',
      busReg: 'MH-12-AK-1120',
      start: DateTime(2026, 9, 17, 7, 0),
      end: DateTime(2026, 9, 17, 18, 0),
      totalFare: 24000,
      amountPaid: 6000,
      stage: BookingStage.confirmed,
    ),
    Booking(
      id: 'bk-0511',
      reference: 'CB-20261002-0511',
      customerId: 'cust_919820011223',
      customerName: 'Rohan Deshmukh',
      customerPhone: '+91 98200 11223',
      route: 'Mumbai → Alibaug',
      capacity: 17,
      busId: 'bus-9902',
      busReg: 'MH-04-CT-9902',
      start: DateTime(2026, 10, 2, 8, 0),
      end: DateTime(2026, 10, 2, 15, 0),
      totalFare: 22000,
      amountPaid: 0,
      stage: BookingStage.costConfirmed,
    ),
    Booking(
      id: 'bk-0480',
      reference: 'CB-20260915-0480',
      customerName: 'Prakash Iyer',
      customerPhone: '+91 98200 77889',
      route: 'Navi Mumbai → Karjat',
      capacity: 17,
      busId: 'bus-9902',
      busReg: 'MH-04-CT-9902',
      start: DateTime(2026, 9, 20, 8, 0),
      end: DateTime(2026, 9, 20, 13, 0),
      totalFare: 0,
      amountPaid: 0,
      stage: BookingStage.requested,
      holdExpiresAt: now.add(const Duration(seconds: 1323)),
    ),
    Booking(
      id: 'bk-0481',
      reference: 'CB-20260915-0481',
      customerName: 'Meera Shah',
      customerPhone: '+91 98200 88990',
      route: 'Thane → Alibaug',
      capacity: 35,
      busId: 'bus-1120',
      busReg: 'MH-12-AK-1120',
      start: DateTime(2026, 9, 21, 8, 0),
      end: DateTime(2026, 9, 21, 16, 0),
      totalFare: 0,
      amountPaid: 0,
      stage: BookingStage.requested,
      holdExpiresAt: now.add(const Duration(seconds: 1661)),
    ),
  ];

  /// The advances behind each booking's `amountPaid`.
  static final List<Payment> payments = [
    Payment(
      id: 'pay-0472-a',
      bookingId: 'bk-0472',
      kind: PaymentKind.advance,
      amount: 4500,
      mode: 'UPI',
      reference: 'UPI/20260908…',
      receivedOn: DateTime(2026, 9, 8),
      recordedBy: 'Admin · Priya',
    ),
    Payment(
      id: 'pay-0473-a',
      bookingId: 'bk-0473',
      kind: PaymentKind.advance,
      amount: 3000,
      mode: 'UPI',
      reference: 'UPI/20260909…',
      receivedOn: DateTime(2026, 9, 9),
      recordedBy: 'Admin · Priya',
    ),
    Payment(
      id: 'pay-0490-a',
      bookingId: 'bk-0490',
      kind: PaymentKind.advance,
      amount: 2500,
      mode: 'Bank transfer',
      reference: 'NEFT/20260910…',
      receivedOn: DateTime(2026, 9, 10),
      recordedBy: 'Admin · Rohit',
    ),
    Payment(
      id: 'pay-0491-a',
      bookingId: 'bk-0491',
      kind: PaymentKind.advance,
      amount: 4500,
      mode: 'UPI',
      reference: 'UPI/20260911…',
      receivedOn: DateTime(2026, 9, 11),
      recordedBy: 'Admin · Priya',
    ),
    Payment(
      id: 'pay-0492-a',
      bookingId: 'bk-0492',
      kind: PaymentKind.advance,
      amount: 6000,
      mode: 'Cash',
      reference: 'Receipt 118',
      receivedOn: DateTime(2026, 9, 12),
      recordedBy: 'Admin · Rohit',
    ),
  ];

  static final List<AppNotification> notifications = [
    AppNotification(
      id: 'ntf-1',
      title: 'Booking confirmed',
      body: 'CB-20260914-0472 is confirmed — Suresh Patil will drive your bus.',
      createdAt: now.subtract(const Duration(minutes: 2)),
      read: false,
      tone: NotificationTone.success,
    ),
    AppNotification(
      id: 'ntf-2',
      title: 'Hold expiring soon',
      body: 'Your held bus for Thane → Mahabaleshwar releases in 5 minutes.',
      createdAt: now.subtract(const Duration(minutes: 18)),
      read: false,
      tone: NotificationTone.urgent,
    ),
    AppNotification(
      id: 'ntf-3',
      title: 'Payment recorded',
      body: '₹4,500 advance recorded by Admin for CB-20260914-0472.',
      createdAt: now.subtract(const Duration(hours: 1)),
      read: true,
      tone: NotificationTone.info,
    ),
    AppNotification(
      id: 'ntf-4',
      title: 'Cost confirmed',
      body: 'Total fare for your Mumbai → Alibaug trip is ₹22,000.',
      createdAt: DateTime(2026, 9, 13, 9, 30),
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

  static final List<AuditEntry> auditLog = [
    AuditEntry(
      id: 'aud-1',
      actor: 'Admin · Priya',
      action: 'Recorded advance payment',
      detail: 'CB-20260914-0472 · ₹4,500 via UPI',
      at: DateTime(2026, 9, 14, 10, 42),
    ),
    AuditEntry(
      id: 'aud-2',
      actor: 'Admin · Priya',
      action: 'Reallocated bus',
      detail: 'CB-20260914-0471 · MH-04-BT-7781 → MH-04-CT-9902',
      at: DateTime(2026, 9, 14, 9, 15),
    ),
    AuditEntry(
      id: 'aud-3',
      actor: 'Admin · Rohit',
      action: 'Cancelled booking',
      detail: 'CB-20260910-0460 · reason: customer requested',
      at: DateTime(2026, 9, 13, 18, 2),
    ),
    AuditEntry(
      id: 'aud-4',
      actor: 'System',
      action: 'Hold expired',
      detail: 'CB-20260910-0458 · released after 30 min',
      at: DateTime(2026, 9, 13, 15, 40),
    ),
  ];

  static const templates = [
    MessageTemplate(
      id: 'tpl-confirmed',
      name: 'Booking confirmed',
      channel: 'Push + Email',
      trigger: 'On advance/full payment recorded',
      preview: 'Your bus is confirmed! {bus}, driver {driver}. Booking {reference}.',
    ),
    MessageTemplate(
      id: 'tpl-cost',
      name: 'Cost confirmed',
      channel: 'Push',
      trigger: 'On Admin recording confirmed cost',
      preview: 'Total fare for your {route} trip is {fare}. Advance due: {advance}.',
    ),
    MessageTemplate(
      id: 'tpl-realloc',
      name: 'Bus reallocated',
      channel: 'Push + Email',
      trigger: 'On Admin reallocation',
      preview: 'Your bus has changed to {bus}. Driver: {driver}. Booking {reference}.',
    ),
    MessageTemplate(
      id: 'tpl-hold',
      name: 'Hold about to expire',
      channel: 'Push (Admin)',
      trigger: 'Before a hold expires',
      preview: '{reference} hold expires in {minutes} minutes.',
    ),
  ];

  static final List<BlackoutEntry> blackouts = [
    BlackoutEntry(
      id: 'blk-1',
      busId: 'bus-7781',
      busReg: 'MH-04-BT-7781',
      reason: 'Annual service',
      from: DateTime(2026, 9, 20),
      to: DateTime(2026, 9, 22),
      isMaintenance: true,
    ),
    BlackoutEntry(
      id: 'blk-2',
      busId: 'bus-1120',
      busReg: 'MH-12-AK-1120',
      reason: 'Vendor-side festival block',
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 3),
    ),
  ];
}
