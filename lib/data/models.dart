/// Minimal, UI-facing models. These exist only to drive the screens in
/// this design round with realistic sample data — Phase 1 replaces them
/// with the real Firestore-backed entities from the BRD's data model.
library;

class BusResult {
  const BusResult({
    required this.id,
    required this.capacity,
    required this.ac,
    required this.seatType,
    required this.available,
    this.photoCount = 4,
    this.amenities = const [],
  });

  final String id;
  final int capacity;
  final bool ac;
  final String seatType;
  final bool available;
  final int photoCount;
  final List<String> amenities;
}

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

enum BookingStatus { requested, costConfirmed, confirmed, inTrip, completed }

class QueueItem {
  const QueueItem({
    required this.reference,
    required this.customerName,
    required this.capacity,
    required this.route,
    required this.pickupWindow,
    required this.holdSecondsLeft,
  });

  final String reference;
  final String customerName;
  final int capacity;
  final String route;
  final String pickupWindow;
  final int holdSecondsLeft;
}

enum CalendarBlockType { available, booked, buffer, blackout }

class CalendarBlock {
  const CalendarBlock({required this.type, this.label});
  final CalendarBlockType type;
  final String? label;
}

class BusCalendarRow {
  const BusCalendarRow({required this.busLabel, required this.blocks});
  final String busLabel;
  final List<CalendarBlock> blocks;
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
  });

  final String regNumber;
  final String vendorName;
  final int capacity;
  final String seatType;
  final bool ac;
  final String baseCity;
  final String driverName;
  final bool active;
}

class DriverRecord {
  const DriverRecord({
    required this.name,
    required this.phone,
    required this.licenceNumber,
    required this.licenceExpiry,
    required this.assignedBus,
    required this.vendorName,
  });

  final String name;
  final String phone;
  final String licenceNumber;
  final String licenceExpiry;
  final String? assignedBus;
  final String vendorName;
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
    required this.busLabel,
    required this.reason,
    required this.from,
    required this.to,
    this.isMaintenance = false,
  });

  final String busLabel;
  final String reason;
  final String from;
  final String to;
  final bool isMaintenance;
}
