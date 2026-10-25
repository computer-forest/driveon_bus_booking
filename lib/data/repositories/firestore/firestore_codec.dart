import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../../models.dart';

/// Maps the app's models to and from Firestore documents. `toMap` returns
/// plain values (DateTime, not Timestamp) so the same maps can be written to
/// the seed file; [encode] / [decode] convert at the Firestore boundary.
class Codec {
  Codec._();

  // --- boundary ----------------------------------------------------------

  /// DateTime -> Timestamp, recursively.
  static dynamic encode(dynamic value) {
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is Map) {
      return <String, dynamic>{for (final e in value.entries) e.key as String: encode(e.value)};
    }
    if (value is List) return [for (final e in value) encode(e)];
    return value;
  }

  /// Timestamp -> DateTime, recursively.
  static dynamic decode(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is Map) {
      return <String, dynamic>{for (final e in value.entries) e.key as String: decode(e.value)};
    }
    if (value is List) return [for (final e in value) decode(e)];
    return value;
  }

  static Map<String, dynamic> decodeMap(Map<String, dynamic> data) =>
      decode(data) as Map<String, dynamic>;

  // --- helpers -----------------------------------------------------------

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;
  static TimeOfDay _time(Object? minutes) {
    final m = (minutes as num?)?.toInt() ?? 0;
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  static String? _str(Object? v) => (v is String && v.isNotEmpty) ? v : null;

  // --- vendors -----------------------------------------------------------

  static Map<String, dynamic> vendorToMap(Vendor v) => {
        'name': v.name,
        'contactPerson': v.contactPerson,
        'phone': v.phone,
        'active': v.active,
        'email': v.email,
        'address': v.address,
        'pan': v.pan,
        'gst': v.gst,
      };

  static Vendor vendorFromMap(String id, Map<String, dynamic> m) => Vendor(
        id: id,
        name: m['name'] as String? ?? '',
        contactPerson: m['contactPerson'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        active: m['active'] as bool? ?? true,
        email: _str(m['email']),
        address: _str(m['address']),
        pan: _str(m['pan']),
        gst: _str(m['gst']),
      );

  // --- drivers -----------------------------------------------------------

  static Map<String, dynamic> driverToMap(DriverRecord d) => {
        'name': d.name,
        'phone': d.phone,
        'vendorId': d.vendorId,
        'vendorName': d.vendorName,
        'licenceNumber': d.licenceNumber,
      };

  static DriverRecord driverFromMap(String id, Map<String, dynamic> m) =>
      DriverRecord(
        id: id,
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        vendorId: m['vendorId'] as String? ?? '',
        vendorName: m['vendorName'] as String? ?? '',
        licenceNumber: _str(m['licenceNumber']),
      );

  // --- buses -------------------------------------------------------------
  // The GPS link is staff-only, so it lives in `busAdmin/{id}` rather than on
  // the bus document customers can read.

  static Map<String, dynamic> busToMap(BusRecord b) => {
        'regNumber': b.regNumber,
        'vendorId': b.vendorId,
        'vendorName': b.vendorName,
        'capacity': b.capacity,
        'seatType': b.seatType,
        'ac': b.ac,
        'baseCity': b.baseCity,
        'driverId': b.driverId,
        'driverName': b.driverName,
        'active': b.active,
        'amenities': b.amenities,
        'photos': [
          for (final p in b.photos)
            {'id': p.id, 'full': p.fullUrl, 'thumb': p.thumbUrl},
        ],
        'weeklyAvailability': [
          for (final d in b.weeklyAvailability)
            {
              'available': d.available,
              'start': _minutes(d.start),
              'end': _minutes(d.end)
            },
        ],
      };

  static BusRecord busFromMap(String id, Map<String, dynamic> m,
      {String? gpsLink}) {
    final week = (m['weeklyAvailability'] as List?) ?? const [];
    return BusRecord(
      id: id,
      regNumber: m['regNumber'] as String? ?? '',
      vendorId: m['vendorId'] as String? ?? '',
      vendorName: m['vendorName'] as String? ?? '',
      capacity: (m['capacity'] as num?)?.toInt() ?? 0,
      seatType: m['seatType'] as String? ?? '',
      ac: m['ac'] as bool? ?? false,
      baseCity: m['baseCity'] as String? ?? '',
      driverId: _str(m['driverId']),
      driverName: m['driverName'] as String? ?? 'Unassigned',
      active: m['active'] as bool? ?? true,
      gpsLink: gpsLink,
      amenities: [
        for (final a in (m['amenities'] as List?) ?? const []) a as String
      ],
      // Older records carried only a count; they have no pictures.
      photos: [
        for (final p in (m['photos'] as List?) ?? const [])
          if (p is Map && p['full'] is String && p['thumb'] is String)
            BusPhoto(
                id: p['id'] as String? ?? '',
                fullUrl: p['full'] as String,
                thumbUrl: p['thumb'] as String),
      ],
      weeklyAvailability: [
        for (var i = 0; i < 7; i++)
          i < week.length
              ? () {
                  final d = week[i] as Map;
                  final available = d['available'] as bool? ?? false;
                  return available
                      ? DayAvailability(
                          available: true,
                          start: _time(d['start']),
                          end: _time(d['end']))
                      : const DayAvailability.closed();
                }()
              : const DayAvailability.closed(),
      ],
    );
  }

  // --- locations / blackouts / templates ---------------------------------

  static Map<String, dynamic> locationToMap(LocationEntry l) => {
        'city': l.city,
        'area': l.area,
        'saved': l.saved,
      };

  static LocationEntry locationFromMap(String id, Map<String, dynamic> m) =>
      LocationEntry(
        id: id,
        city: m['city'] as String? ?? '',
        area: m['area'] as String? ?? '',
        saved: m['saved'] as bool? ?? false,
      );

  static Map<String, dynamic> blackoutToMap(BlackoutEntry e) => {
        'busId': e.busId,
        'busReg': e.busReg,
        'reason': e.reason,
        'from': e.from,
        'to': e.to,
        'isMaintenance': e.isMaintenance,
      };

  static BlackoutEntry blackoutFromMap(String id, Map<String, dynamic> m) =>
      BlackoutEntry(
        id: id,
        busId: m['busId'] as String? ?? '',
        busReg: m['busReg'] as String? ?? '',
        reason: m['reason'] as String? ?? '',
        from: m['from'] as DateTime,
        to: m['to'] as DateTime,
        isMaintenance: m['isMaintenance'] as bool? ?? false,
      );

  static Map<String, dynamic> templateToMap(MessageTemplate t) => {
        'name': t.name,
        'channel': t.channel,
        'trigger': t.trigger,
        'preview': t.preview,
      };

  static MessageTemplate templateFromMap(String id, Map<String, dynamic> m) =>
      MessageTemplate(
        id: id,
        name: m['name'] as String? ?? '',
        channel: m['channel'] as String? ?? '',
        trigger: m['trigger'] as String? ?? '',
        preview: m['preview'] as String? ?? '',
      );

  // --- config ------------------------------------------------------------

  static Map<String, dynamic> configToMap(AppConfig c) => {
        'holdMinutes': c.holdMinutes,
        'preBufferMinutes': c.preBufferMinutes,
        'postBufferMinutes': c.postBufferMinutes,
        'defaultAdvancePercent': c.defaultAdvancePercent,
        'supportPhone': c.supportPhone,
        'whatsappNumber': c.whatsappNumber,
        'capacities': c.capacities,
        'packageNote': c.packageNote,
      };

  static AppConfig configFromMap(Map<String, dynamic> m) {
    const d = AppConfig();
    return AppConfig(
      holdMinutes: (m['holdMinutes'] as num?)?.toInt() ?? d.holdMinutes,
      preBufferMinutes:
          (m['preBufferMinutes'] as num?)?.toInt() ?? d.preBufferMinutes,
      postBufferMinutes:
          (m['postBufferMinutes'] as num?)?.toInt() ?? d.postBufferMinutes,
      defaultAdvancePercent: (m['defaultAdvancePercent'] as num?)?.toInt() ??
          d.defaultAdvancePercent,
      supportPhone: m['supportPhone'] as String? ?? d.supportPhone,
      whatsappNumber: m['whatsappNumber'] as String? ?? d.whatsappNumber,
      capacities: [
        for (final c in (m['capacities'] as List?) ?? d.capacities)
          (c as num).toInt()
      ],
      packageNote: m['packageNote'] as String? ?? d.packageNote,
    );
  }

  // --- packages / faqs / audit -------------------------------------------

  static Map<String, dynamic> packageToMap(PackageLocation p,
          {int? order}) =>
      {
        'city': p.city,
        'order': order ?? p.order,
        'packages': [
          for (final s in p.packages)
            {
              'seater': s.seater,
              'sampleRates': s.sampleRates,
              'trips': [
                for (final t in s.trips)
                  {
                    'destination': t.destination,
                    'oneDayRate': t.oneDayRate,
                    'twoDayRate': t.twoDayRate
                  },
              ],
            },
        ],
      };

  static PackageLocation packageFromMap(Map<String, dynamic> m,
          {String? id}) =>
      PackageLocation(
        id: id,
        order: (m['order'] as num?)?.toInt() ?? 0,
        city: m['city'] as String? ?? '',
        packages: [
          for (final s in (m['packages'] as List?) ?? const [])
            SeaterPackage(
              seater: (s as Map)['seater'] as String? ?? '',
              sampleRates: s['sampleRates'] as bool? ?? false,
              trips: [
                for (final t in (s['trips'] as List?) ?? const [])
                  PackageTrip(
                    destination: (t as Map)['destination'] as String? ?? '',
                    oneDayRate: (t['oneDayRate'] as num?)?.toInt() ?? 0,
                    twoDayRate: (t['twoDayRate'] as num?)?.toInt() ?? 0,
                  ),
              ],
            ),
        ],
      );

  static Map<String, dynamic> faqToMap(FaqItem f, {int order = 0}) =>
      {'question': f.question, 'answer': f.answer, 'order': order};

  static FaqItem faqFromMap(Map<String, dynamic> m) => FaqItem(
      question: m['question'] as String? ?? '',
      answer: m['answer'] as String? ?? '');

  static AuditEntry auditFromMap(String id, Map<String, dynamic> m) =>
      AuditEntry(
        id: id,
        actor: m['actor'] as String? ?? '',
        action: m['action'] as String? ?? '',
        detail: m['detail'] as String? ?? '',
        at: (m['at'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  // --- bookings, payments, ratings, cancellations -------------------------
  // Written only by the server (Cloud Functions); the app reads them.

  static Booking bookingFromMap(String id, Map<String, dynamic> m) => Booking(
        id: id,
        reference: m['reference'] as String? ?? '',
        customerId: _str(m['customerId']),
        customerName: m['customerName'] as String? ?? '',
        customerPhone: m['customerPhone'] as String? ?? '',
        route: m['route'] as String? ?? '',
        capacity: (m['capacity'] as num?)?.toInt() ?? 0,
        busId: m['busId'] as String? ?? '',
        busReg: m['busReg'] as String? ?? '',
        start: m['start'] as DateTime,
        end: m['end'] as DateTime,
        totalFare: (m['totalFare'] as num?)?.toInt() ?? 0,
        amountPaid: (m['amountPaid'] as num?)?.toInt() ?? 0,
        stage: BookingStage.values.asNameMap()[m['stage']] ??
            BookingStage.requested,
        holdExpiresAt: m['holdExpiresAt'] as DateTime?,
        pickupLandmark: _str(m['pickupLandmark']),
        createdAt: m['createdAt'] as DateTime?,
        confirmedAt: m['confirmedAt'] as DateTime?,
        refundedAmount: (m['refundedAmount'] as num?)?.toInt() ?? 0,
        driverPhone: _str(m['driverPhone']),
        gpsLink: _str(m['gpsLink']),
      );

  static Payment paymentFromMap(String id, Map<String, dynamic> m) => Payment(
        id: id,
        bookingId: m['bookingId'] as String? ?? '',
        kind: PaymentKind.values.asNameMap()[m['kind']] ?? PaymentKind.advance,
        amount: (m['amount'] as num?)?.toInt() ?? 0,
        mode: m['mode'] as String? ?? '',
        reference: m['reference'] as String? ?? '',
        receivedOn: (m['receivedOn'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        recordedBy: m['recordedBy'] as String? ?? '',
      );

  static Map<String, dynamic> ratingToMap(Rating r) => {
        'bookingId': r.bookingId,
        'bus': r.bus,
        'driver': r.driver,
        'overall': r.overall,
        'feedback': r.feedback,
      };

  static Map<String, dynamic> cancellationToMap(CancellationRequest c) => {
        'bookingId': c.bookingId,
        'requestedBy': c.requestedBy,
        'reason': c.reason,
        'status': c.status.name,
      };

  static CancellationRequest cancellationFromMap(
          String id, Map<String, dynamic> m) =>
      CancellationRequest(
        id: id,
        bookingId: m['bookingId'] as String? ?? '',
        requestedBy: m['requestedBy'] as String? ?? '',
        reason: m['reason'] as String? ?? '',
        status: CancellationStatus.values.asNameMap()[m['status']] ??
            CancellationStatus.pending,
        createdAt: (m['createdAt'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        decisionNote: m['decisionNote'] as String? ?? '',
        refundAmount: (m['refundAmount'] as num?)?.toInt() ?? 0,
      );

  static AppNotification notificationFromMap(
          String id, Map<String, dynamic> m) =>
      AppNotification(
        id: id,
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        // A notification just written by the server has no timestamp for a moment.
        createdAt: (m['createdAt'] as DateTime?) ?? DateTime.now(),
        read: m['read'] as bool? ?? false,
        tone: NotificationTone.values.asNameMap()[m['tone']] ??
            NotificationTone.info,
        bookingId: _str(m['bookingId']),
      );

  // --- legal text ----------------------------------------------------------

  static List<Map<String, dynamic>> legalToMap(List<LegalSection> sections) => [
        for (final s in sections) {'heading': s.heading, 'body': s.body},
      ];

  static LegalDocument legalFromMap(Map<String, dynamic> m) => LegalDocument(
        sections: [
          for (final s in (m['sections'] as List?) ?? const [])
            if (s is Map)
              LegalSection(
                heading: s['heading'] is String ? s['heading'] as String : '',
                body: s['body'] is String ? s['body'] as String : '',
              ),
        ],
        updatedAt: m['updatedAt'] as DateTime?,
      );

  static Rating ratingFromMap(String id, Map<String, dynamic> m) => Rating(
        id: id,
        bookingId: m['bookingId'] is String ? m['bookingId'] as String : '',
        // Customers write these, so read them defensively: one odd value must
        // not break the staff screen for everyone.
        bus: m['bus'] is num ? (m['bus'] as num).toInt() : 0,
        driver: m['driver'] is num ? (m['driver'] as num).toInt() : 0,
        overall: m['overall'] is num ? (m['overall'] as num).toInt() : 0,
        feedback: m['feedback'] is String ? m['feedback'] as String : '',
        // A rating just written has no server time for a moment.
        createdAt: (m['createdAt'] as DateTime?) ?? DateTime.now(),
      );
}
