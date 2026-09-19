import 'models.dart';

class MockData {
  MockData._();

  static const busResults = [
    BusResult(
      id: 'BUS-7781',
      capacity: 20,
      ac: true,
      seatType: 'Pushback seats',
      available: true,
      amenities: ['AC', 'Pushback seats', 'Reading lights', 'Charging points'],
    ),
    BusResult(
      id: 'BUS-9902',
      capacity: 17,
      ac: true,
      seatType: 'Pushback seats',
      available: true,
      amenities: ['AC', 'Pushback seats', 'Music system'],
    ),
    BusResult(
      id: 'BUS-1120',
      capacity: 35,
      ac: false,
      seatType: 'Highback seats',
      available: true,
      amenities: ['Highback seats', 'Extra legroom'],
    ),
  ];

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

  static const queue = [
    QueueItem(
      reference: 'CB-20260914-0472',
      customerName: 'Rohan Deshmukh',
      capacity: 20,
      route: 'Thane → Mahabaleshwar',
      pickupWindow: '14 Sep, 6:00 AM',
      holdSecondsLeft: 252,
    ),
    QueueItem(
      reference: 'CB-20260914-0473',
      customerName: 'Anita Kulkarni',
      capacity: 17,
      route: 'Mumbai → Lonavala',
      pickupWindow: '15 Sep, 7:30 AM',
      holdSecondsLeft: 710,
    ),
    QueueItem(
      reference: 'CB-20260915-0480',
      customerName: 'Prakash Iyer',
      capacity: 40,
      route: 'Navi Mumbai → Karjat',
      pickupWindow: '20 Sep, 8:00 AM',
      holdSecondsLeft: 1323,
    ),
    QueueItem(
      reference: 'CB-20260915-0481',
      customerName: 'Meera Shah',
      capacity: 35,
      route: 'Thane → Alibaug',
      pickupWindow: '21 Sep, 5:30 AM',
      holdSecondsLeft: 1661,
    ),
  ];

  static const calendarRows = [
    BusCalendarRow(busLabel: 'MH-04-BT-7781 · 20 seater', blocks: [
      CalendarBlock(type: CalendarBlockType.available),
      CalendarBlock(type: CalendarBlockType.available),
      CalendarBlock(type: CalendarBlockType.booked, label: 'CB-72'),
      CalendarBlock(type: CalendarBlockType.buffer),
      CalendarBlock(type: CalendarBlockType.available),
      CalendarBlock(type: CalendarBlockType.blackout),
      CalendarBlock(type: CalendarBlockType.blackout),
    ]),
    BusCalendarRow(busLabel: 'MH-04-CT-9902 · 17 seater', blocks: [
      CalendarBlock(type: CalendarBlockType.available),
      CalendarBlock(type: CalendarBlockType.booked, label: 'CB-51'),
      CalendarBlock(type: CalendarBlockType.buffer),
      CalendarBlock(type: CalendarBlockType.available),
      CalendarBlock(type: CalendarBlockType.available),
      CalendarBlock(type: CalendarBlockType.available),
      CalendarBlock(type: CalendarBlockType.available),
    ]),
    BusCalendarRow(busLabel: 'MH-12-AK-1120 · 35 seater', blocks: [
      CalendarBlock(type: CalendarBlockType.available),
      CalendarBlock(type: CalendarBlockType.available),
      CalendarBlock(type: CalendarBlockType.available),
      CalendarBlock(type: CalendarBlockType.booked, label: 'CB-80'),
      CalendarBlock(type: CalendarBlockType.buffer),
      CalendarBlock(type: CalendarBlockType.available),
      CalendarBlock(type: CalendarBlockType.available),
    ]),
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

  static const buses = [
    BusRecord(
      regNumber: 'MH-04-BT-7781',
      vendorName: 'Neeta Travels',
      capacity: 20,
      seatType: 'Pushback seats',
      ac: true,
      baseCity: 'Thane',
      driverName: 'Suresh Patil',
      active: true,
    ),
    BusRecord(
      regNumber: 'MH-04-CT-9902',
      vendorName: 'Neeta Travels',
      capacity: 17,
      seatType: 'Pushback seats',
      ac: true,
      baseCity: 'Thane',
      driverName: 'Ramesh Jadhav',
      active: true,
    ),
    BusRecord(
      regNumber: 'MH-12-AK-1120',
      vendorName: 'Shivneri Coaches',
      capacity: 35,
      seatType: 'Highback seats',
      ac: false,
      baseCity: 'Pune',
      driverName: 'Vikas More',
      active: true,
    ),
    BusRecord(
      regNumber: 'MH-14-DE-5567',
      vendorName: 'Shivneri Coaches',
      capacity: 40,
      seatType: 'Pushback seats',
      ac: true,
      baseCity: 'Pune',
      driverName: 'Unassigned',
      active: false,
    ),
  ];

  static const drivers = [
    DriverRecord(
      name: 'Suresh Patil',
      phone: '+91 90000 11122',
      licenceNumber: 'MH04 20180012345',
      licenceExpiry: '12 Mar 2027',
      assignedBus: 'MH-04-BT-7781',
      vendorName: 'Neeta Travels',
    ),
    DriverRecord(
      name: 'Ramesh Jadhav',
      phone: '+91 90000 22233',
      licenceNumber: 'MH04 20170034567',
      licenceExpiry: '30 Nov 2026',
      assignedBus: 'MH-04-CT-9902',
      vendorName: 'Neeta Travels',
    ),
    DriverRecord(
      name: 'Vikas More',
      phone: '+91 90000 33344',
      licenceNumber: 'MH12 20190056789',
      licenceExpiry: '05 Jan 2028',
      assignedBus: 'MH-12-AK-1120',
      vendorName: 'Shivneri Coaches',
    ),
    DriverRecord(
      name: 'Pramod Kale',
      phone: '+91 90000 44455',
      licenceNumber: 'MH12 20200078901',
      licenceExpiry: '18 Jun 2027',
      assignedBus: null,
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

  static const blackouts = [
    BlackoutEntry(
      busLabel: 'MH-04-BT-7781 · 20 seater',
      reason: 'Annual service',
      from: '20 Sep',
      to: '22 Sep',
      isMaintenance: true,
    ),
    BlackoutEntry(
      busLabel: 'MH-12-AK-1120 · 35 seater',
      reason: 'Vendor-side festival block',
      from: '1 Oct',
      to: '3 Oct',
    ),
  ];
}
