/// Minimal, UI-facing models. These exist only to drive the screens in
/// this design round with realistic sample data — Phase 1 replaces them
/// with the real Firestore-backed entities from the BRD's data model.
library;

import 'package:flutter/material.dart' show TimeOfDay;

DateTime combineDateTime(DateTime day, TimeOfDay time) =>
    DateTime(day.year, day.month, day.day, time.hour, time.minute);

class DriverInfo {
  const DriverInfo({required this.name, required this.phone, required this.busNumber});

  final String name;
  final String phone;
  final String busNumber;
}

class LedgerEntry {
  const LedgerEntry({required this.label, required this.amount, this.note});

  final String label;
  final String amount;
  final String? note;
}

enum BookingStage { requested, confirmed, inTrip, completed, settled }

/// One charter, from the moment the customer holds a bus through to
/// settlement. The queue shows the holds, the calendar shows the rest.
class Booking {
  const Booking({
    required this.reference,
    required this.customerName,
    required this.customerPhone,
    required this.route,
    required this.capacity,
    required this.busReg,
    required this.start,
    required this.end,
    required this.totalFare,
    required this.amountPaid,
    required this.stage,
    this.holdSecondsLeft = 0,
  });

  final String reference;
  final String customerName;
  final String customerPhone;
  final String route;
  final int capacity;

  /// A bus is held the moment the customer selects it, so even a pending
  /// request occupies its slot — that is why this is never null.
  final String busReg;
  final DateTime start;
  final DateTime end;
  final int totalFare;
  final int amountPaid;
  final BookingStage stage;
  final int holdSecondsLeft;

  int get balanceDue => totalFare - amountPaid;
  bool get isHold => stage == BookingStage.requested;

  Booking copyWith({BookingStage? stage, String? busReg, int? amountPaid}) => Booking(
        reference: reference,
        customerName: customerName,
        customerPhone: customerPhone,
        route: route,
        capacity: capacity,
        busReg: busReg ?? this.busReg,
        start: start,
        end: end,
        totalFare: totalFare,
        amountPaid: amountPaid ?? this.amountPaid,
        stage: stage ?? this.stage,
        holdSecondsLeft: holdSecondsLeft,
      );
}

/// City/area entry from the Admin-maintained location list (BRD: no map
/// services — locations are picked from this list plus a free-text
/// landmark line).
class LocationEntry {
  const LocationEntry({required this.city, required this.area, this.saved = false});
  final String city;
  final String area;
  final bool saved;

  String get label => '$area, $city';
}

class Vendor {
  const Vendor({
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.busCount,
    required this.active,
  });

  final String name;
  final String contactPerson;
  final String phone;
  final int busCount;
  final bool active;
}

/// One weekday's charter window for a bus. Admin sets these per bus on the
/// bus form; search and the calendar both read them.
class DayAvailability {
  const DayAvailability({
    required this.available,
    this.start = const TimeOfDay(hour: 6, minute: 0),
    this.end = const TimeOfDay(hour: 22, minute: 0),
  });

  const DayAvailability.closed()
      : available = false,
        start = const TimeOfDay(hour: 6, minute: 0),
        end = const TimeOfDay(hour: 22, minute: 0);

  final bool available;
  final TimeOfDay start;
  final TimeOfDay end;

  DayAvailability copyWith({bool? available, TimeOfDay? start, TimeOfDay? end}) => DayAvailability(
        available: available ?? this.available,
        start: start ?? this.start,
        end: end ?? this.end,
      );
}

class BusRecord {
  const BusRecord({
    required this.regNumber,
    required this.vendorName,
    required this.capacity,
    required this.seatType,
    required this.ac,
    required this.baseCity,
    required this.driverName,
    required this.active,
    required this.weeklyAvailability,
    this.amenities = const [],
    this.photoCount = 4,
  });

  final String regNumber;
  final String vendorName;
  final int capacity;
  final String seatType;
  final bool ac;
  final String baseCity;
  final String driverName;
  final bool active;

  /// Exactly 7 entries, index 0 = Monday, so `weeklyAvailability[d.weekday - 1]`.
  final List<DayAvailability> weeklyAvailability;
  final List<String> amenities;
  final int photoCount;

  String get label => '$regNumber · $capacity seater';
}

class DriverRecord {
  const DriverRecord({
    required this.name,
    required this.phone,
    required this.vendorName,
    this.licenceNumber,
  });

  final String name;
  final String phone;
  final String vendorName;
  final String? licenceNumber;
}

/// What the customer asked for on the search form, carried through to
/// results so availability can actually be applied.
class SearchCriteria {
  const SearchCriteria({
    required this.pickup,
    required this.drop,
    required this.pickupDate,
    required this.pickupTime,
    required this.dropDate,
    required this.dropTime,
    required this.isRoundTrip,
    required this.returnDate,
    required this.returnTime,
    required this.summary,
    this.capacity,
  });

  final LocationEntry pickup;
  final LocationEntry drop;
  final DateTime pickupDate;
  final TimeOfDay pickupTime;
  final DateTime dropDate;
  final TimeOfDay dropTime;
  final bool isRoundTrip;
  final DateTime returnDate;
  final TimeOfDay returnTime;
  final String summary;
  final int? capacity;

  DateTime get startsAt => combineDateTime(pickupDate, pickupTime);

  /// On a round trip the bus stays with the customer throughout, so the
  /// hold runs to the return instant rather than the outbound drop.
  DateTime get endsAt =>
      isRoundTrip ? combineDateTime(returnDate, returnTime) : combineDateTime(dropDate, dropTime);
}

enum NotificationTone { info, success, warning, urgent }

class AppNotification {
  const AppNotification({
    required this.title,
    required this.body,
    required this.time,
    required this.read,
    this.tone = NotificationTone.info,
  });

  final String title;
  final String body;
  final String time;
  final bool read;
  final NotificationTone tone;
}

class FaqItem {
  const FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;
}

class ReportMetric {
  const ReportMetric({required this.label, required this.value, this.sublabel});
  final String label;
  final String value;
  final String? sublabel;
}

class AuditEntry {
  const AuditEntry({
    required this.actor,
    required this.action,
    required this.detail,
    required this.time,
  });

  final String actor;
  final String action;
  final String detail;
  final String time;
}

class MessageTemplate {
  const MessageTemplate({
    required this.name,
    required this.channel,
    required this.trigger,
    required this.preview,
  });

  final String name;
  final String channel;
  final String trigger;
  final String preview;
}

class BlackoutEntry {
  const BlackoutEntry({
    required this.busReg,
    required this.reason,
    required this.from,
    required this.to,
    this.isMaintenance = false,
  });

  final String busReg;
  final String reason;
  final DateTime from;
  final DateTime to;
  final bool isMaintenance;
}
