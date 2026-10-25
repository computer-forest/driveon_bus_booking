/// Domain models. Relations between records are by id; the matching name
/// fields (`vendorName`, `driverName`, `busReg`) are display snapshots kept
/// alongside, so a list can render without a join. Renaming the source
/// record must update its snapshots (a Cloud Function in Stage 2).
library;

import 'package:flutter/material.dart' show TimeOfDay;

DateTime combineDateTime(DateTime day, TimeOfDay time) =>
    DateTime(day.year, day.month, day.day, time.hour, time.minute);

enum UserRole { customer, admin }

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    this.name,
    this.phone,
    this.email,
    this.onboarded = false,
    this.createdAt,
  });

  final String id;
  final UserRole role;
  final String? name;
  final String? phone;
  final String? email;

  /// Customer has finished the first-sign-in steps (profile, then
  /// biometric or PIN). Always true for admins, who are issued accounts.
  final bool onboarded;
  final DateTime? createdAt;

  bool get isAdmin => role == UserRole.admin;

  AppUser copyWith({String? name, String? email, bool? onboarded}) => AppUser(
        id: id,
        role: role,
        name: name ?? this.name,
        phone: phone,
        email: email ?? this.email,
        onboarded: onboarded ?? this.onboarded,
        createdAt: createdAt,
      );
}

/// Which optional push messages a customer wants. Fares, confirmations,
/// cancellations and bus changes are always sent, so they are not here.
class PushPrefs {
  const PushPrefs({this.reminders = true, this.tripUpdates = true});

  /// Hold placed, about to run out, or expired.
  final bool reminders;

  /// Trip started, completed, and fully paid.
  final bool tripUpdates;

  PushPrefs copyWith({bool? reminders, bool? tripUpdates}) =>
      PushPrefs(reminders: reminders ?? this.reminders, tripUpdates: tripUpdates ?? this.tripUpdates);
}

/// Global settings the availability engine and booking flow read. One
/// document; admins edit it from the masters screen.
class AppConfig {
  const AppConfig({
    this.holdMinutes = 30,
    this.preBufferMinutes = 45,
    this.postBufferMinutes = 45,
    this.defaultAdvancePercent = 25,
    this.supportPhone = '+91 99877 74832',
    this.whatsappNumber = '+91 99877 74832',
    this.capacities = const [17, 20, 27, 30, 35, 40],
    this.packageNote = defaultPackageNote,
  });

  /// Shown under every rate chart; staff can reword it.
  static const defaultPackageNote =
      'Rates exclude toll, parking and entry charges, which are paid by the customer.';

  final int holdMinutes;
  final int preBufferMinutes;
  final int postBufferMinutes;
  final int defaultAdvancePercent;
  final String supportPhone;
  final String whatsappNumber;
  final List<int> capacities;
  final String packageNote;

  Duration get holdDuration => Duration(minutes: holdMinutes);
  Duration get preBuffer => Duration(minutes: preBufferMinutes);
  Duration get postBuffer => Duration(minutes: postBufferMinutes);

  /// Advance owed for [totalFare], from the configured percentage.
  int advanceFor(int totalFare) =>
      (totalFare * defaultAdvancePercent / 100).round();

  AppConfig copyWith({
    int? holdMinutes,
    int? preBufferMinutes,
    int? postBufferMinutes,
    int? defaultAdvancePercent,
    String? supportPhone,
    String? whatsappNumber,
    List<int>? capacities,
    String? packageNote,
  }) =>
      AppConfig(
        holdMinutes: holdMinutes ?? this.holdMinutes,
        preBufferMinutes: preBufferMinutes ?? this.preBufferMinutes,
        postBufferMinutes: postBufferMinutes ?? this.postBufferMinutes,
        defaultAdvancePercent:
            defaultAdvancePercent ?? this.defaultAdvancePercent,
        supportPhone: supportPhone ?? this.supportPhone,
        whatsappNumber: whatsappNumber ?? this.whatsappNumber,
        capacities: capacities ?? this.capacities,
        packageNote: packageNote ?? this.packageNote,
      );
}

class DriverInfo {
  const DriverInfo(
      {required this.name, this.phone = '', required this.busNumber});

  final String name;

  /// Empty until the contact is shared with the customer.
  final String phone;
  final String busNumber;
}

class LedgerEntry {
  const LedgerEntry({required this.label, required this.amount, this.note});

  final String label;
  final String amount;
  final String? note;
}

enum BookingStage {
  requested,
  costConfirmed,
  confirmed,
  inTrip,
  completed,
  settled,

  /// A hold that ran out before staff confirmed it. The bus was released.
  expired,

  /// Cancelled by staff. The bus was released.
  cancelled,
}

/// One charter, from the moment the customer holds a bus through to
/// settlement. The queue shows the holds, the calendar shows the rest.
class Booking {
  const Booking({
    required this.id,
    required this.reference,
    required this.customerName,
    required this.customerPhone,
    required this.route,
    required this.capacity,
    required this.busId,
    required this.busReg,
    required this.start,
    required this.end,
    required this.totalFare,
    required this.amountPaid,
    required this.stage,
    this.customerId,
    this.holdExpiresAt,
    this.pickupLandmark,
    this.createdAt,
    this.confirmedAt,
    this.refundedAmount = 0,
    this.driverPhone,
    this.gpsLink,
  });

  final String id;
  final String reference;
  final String? customerId;
  final String customerName;
  final String customerPhone;
  final String route;
  final int capacity;

  /// A bus is held the moment the customer selects it, so even a pending
  /// request occupies its slot — that is why these are never null.
  final String busId;
  final String busReg;
  final DateTime start;
  final DateTime end;
  final int totalFare;
  final int amountPaid;
  final BookingStage stage;

  /// When an unconfirmed hold lapses. Set only while [stage] is requested;
  /// the server is the authority, the client just counts down to it.
  final DateTime? holdExpiresAt;
  final String? pickupLandmark;

  /// When the customer held the bus, and when staff confirmed it. Set by the
  /// server; they feed the reports.
  final DateTime? createdAt;
  final DateTime? confirmedAt;

  /// The driver's number and the bus's tracking link, copied onto the booking
  /// by the server when staff confirm it. Null until then.
  final String? driverPhone;
  final String? gpsLink;

  /// Money paid back after a cancellation. [amountPaid] is net of it.
  final int refundedAmount;

  int get balanceDue => totalFare - amountPaid;
  bool get isHold => stage == BookingStage.requested;

  /// Whether this booking still takes its bus: not cancelled or expired.
  bool get occupiesBus =>
      stage != BookingStage.expired && stage != BookingStage.cancelled;

  /// Whole seconds left on the hold at [now], never negative.
  int holdSecondsLeft(DateTime now) {
    final expires = holdExpiresAt;
    if (expires == null) return 0;
    final left = expires.difference(now).inSeconds;
    return left < 0 ? 0 : left;
  }

  Booking copyWith({
    BookingStage? stage,
    String? busId,
    String? busReg,
    int? totalFare,
    int? amountPaid,
    int? refundedAmount,
    String? driverPhone,
    String? gpsLink,
  }) =>
      Booking(
        id: id,
        reference: reference,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        route: route,
        capacity: capacity,
        busId: busId ?? this.busId,
        busReg: busReg ?? this.busReg,
        start: start,
        end: end,
        totalFare: totalFare ?? this.totalFare,
        amountPaid: amountPaid ?? this.amountPaid,
        stage: stage ?? this.stage,
        holdExpiresAt: holdExpiresAt,
        pickupLandmark: pickupLandmark,
        createdAt: createdAt,
        confirmedAt: confirmedAt,
        refundedAmount: refundedAmount ?? this.refundedAmount,
        driverPhone: driverPhone ?? this.driverPhone,
        gpsLink: gpsLink ?? this.gpsLink,
      );
}

/// City/area entry from the Admin-maintained location list (BRD: no map
/// services — locations are picked from this list plus a free-text
/// landmark line).
class LocationEntry {
  const LocationEntry(
      {this.id = '',
      required this.city,
      required this.area,
      this.saved = false});
  final String id;
  final String city;
  final String area;
  final bool saved;

  String get label => '$area, $city';
}

class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.active,
    this.email,
    this.address,
    this.pan,
    this.gst,
  });

  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final bool active;
  final String? email;
  final String? address;
  final String? pan;
  final String? gst;
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

  DayAvailability copyWith(
          {bool? available, TimeOfDay? start, TimeOfDay? end}) =>
      DayAvailability(
        available: available ?? this.available,
        start: start ?? this.start,
        end: end ?? this.end,
      );
}

class BusRecord {
  const BusRecord({
    required this.id,
    required this.regNumber,
    required this.vendorId,
    required this.vendorName,
    required this.capacity,
    required this.seatType,
    required this.ac,
    required this.baseCity,
    required this.driverName,
    required this.active,
    required this.weeklyAvailability,
    this.driverId,
    this.gpsLink,
    this.amenities = const [],
    this.photos = const [],
  });

  final String id;
  final String regNumber;
  final String vendorId;
  final String vendorName;
  final int capacity;
  final String seatType;
  final bool ac;
  final String baseCity;

  /// Null while no driver is assigned; [driverName] then reads 'Unassigned'.
  final String? driverId;
  final String driverName;
  final bool active;
  final String? gpsLink;

  /// Exactly 7 entries, index 0 = Monday, so `weeklyAvailability[d.weekday - 1]`.
  final List<DayAvailability> weeklyAvailability;
  final List<String> amenities;

  /// Up to [maxPhotos] pictures, the first being the cover. Empty until staff
  /// add some, in which case customers see a neutral bus picture.
  final List<BusPhoto> photos;

  static const maxPhotos = 4;

  int get photoCount => photos.length;
  BusPhoto? get cover => photos.isEmpty ? null : photos.first;

  String get label => '$regNumber · $capacity seater';
}

/// One bus picture, in two sizes. The files are immutable (a new upload always
/// gets a new id), which is what lets phones cache them for a year.
class BusPhoto {
  const BusPhoto(
      {required this.id, required this.fullUrl, required this.thumbUrl});

  final String id;

  /// About 1280 px on the long side, for the bus page.
  final String fullUrl;

  /// About 360 px, for lists.
  final String thumbUrl;

  @override
  bool operator ==(Object other) =>
      other is BusPhoto &&
      other.id == id &&
      other.fullUrl == fullUrl &&
      other.thumbUrl == thumbUrl;

  @override
  int get hashCode => Object.hash(id, fullUrl, thumbUrl);
}

class DriverRecord {
  const DriverRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.vendorId,
    required this.vendorName,
    this.licenceNumber,
  });

  final String id;
  final String name;
  final String phone;
  final String vendorId;
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
    this.pickupLandmark = '',
  });

  final LocationEntry pickup;

  /// Free-text landmark that pins down the pickup point within the area.
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
  final String pickupLandmark;

  DateTime get startsAt => combineDateTime(pickupDate, pickupTime);

  /// On a round trip the bus stays with the customer throughout, so the
  /// hold runs to the return instant rather than the outbound drop.
  DateTime get endsAt => isRoundTrip
      ? combineDateTime(returnDate, returnTime)
      : combineDateTime(dropDate, dropTime);
}

/// One destination on a fixed-rate outstation package chart.
class PackageTrip {
  const PackageTrip({
    required this.destination,
    required this.oneDayRate,
    required this.twoDayRate,
  });

  final String destination;
  final int oneDayRate;
  final int twoDayRate;
}

/// The rate chart for one seater class leaving one city.
class SeaterPackage {
  const SeaterPackage({
    required this.seater,
    required this.trips,
    this.sampleRates = false,
  });

  final String seater;
  final List<PackageTrip> trips;

  /// True where the client has not supplied real rates yet, so the chart
  /// can say so rather than passing placeholders off as quotable prices.
  final bool sampleRates;
}

/// A city customers can start a packaged outstation trip from.
class PackageLocation {
  const PackageLocation({required this.city, required this.packages, this.id, this.order = 0});

  final String city;
  final List<SeaterPackage> packages;

  /// The document id; null for a city staff have not saved yet.
  final String? id;

  /// Where the city sits in the list customers see.
  final int order;

  /// The document id a new city gets: its name, lower-cased, with dashes.
  static String idFor(String city) =>
      city.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}

enum NotificationTone { info, success, warning, urgent }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.tone = NotificationTone.info,
    this.bookingId,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final NotificationTone tone;

  /// The booking this is about, so tapping it can open that booking.
  final String? bookingId;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        createdAt: createdAt,
        read: read ?? this.read,
        tone: tone,
        bookingId: bookingId,
      );
}

/// One headed block of a legal text.
/// Someone with staff access. [phone] is the 12-digit number with country
/// code (91 + the 10 digits), which is also the document id and how the
/// person signs in.
class StaffMember {
  const StaffMember({required this.phone, required this.name, required this.active});

  final String phone;
  final String name;
  final bool active;

  /// `+91 98200 00001`.
  String get displayPhone {
    final d = phone.length >= 10 ? phone.substring(phone.length - 10) : phone;
    return d.length == 10 ? '+91 ${d.substring(0, 5)} ${d.substring(5)}' : phone;
  }

  StaffMember copyWith({String? name, bool? active}) =>
      StaffMember(phone: phone, name: name ?? this.name, active: active ?? this.active);
}

/// One headed block of a legal text.
class LegalSection {
  const LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;

  @override
  bool operator ==(Object other) => other is LegalSection && other.heading == heading && other.body == body;

  @override
  int get hashCode => Object.hash(heading, body);
}

/// The Terms & Conditions or the Privacy Policy. Staff edit them in the app,
/// so the wording can change without a new release.
class LegalDocument {
  const LegalDocument({required this.sections, this.updatedAt});

  final List<LegalSection> sections;

  /// Set by the server when staff last saved it.
  final DateTime? updatedAt;

  bool get isEmpty => sections.isEmpty;
}

/// Which legal text. The names are the document ids in Firestore.
enum LegalKind {
  terms('Terms & Conditions'),
  privacy('Privacy Policy');

  const LegalKind(this.title);
  final String title;
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
    required this.id,
    required this.actor,
    required this.action,
    required this.detail,
    required this.at,
  });

  final String id;
  final String actor;
  final String action;
  final String detail;
  final DateTime at;
}

class MessageTemplate {
  const MessageTemplate({
    required this.id,
    required this.name,
    required this.channel,
    required this.trigger,
    required this.preview,
  });

  final String id;
  final String name;
  final String channel;
  final String trigger;
  final String preview;

  MessageTemplate copyWith({String? preview}) => MessageTemplate(
        id: id,
        name: name,
        channel: channel,
        trigger: trigger,
        preview: preview ?? this.preview,
      );
}

class BlackoutEntry {
  const BlackoutEntry({
    required this.id,
    required this.busId,
    required this.busReg,
    required this.reason,
    required this.from,
    required this.to,
    this.isMaintenance = false,
  });

  final String id;
  final String busId;
  final String busReg;
  final String reason;
  final DateTime from;
  final DateTime to;
  final bool isMaintenance;
}

enum PaymentKind { advance, balance, refund }

/// Money recorded by an admin after it changed hands outside the app.
/// There is no gateway: every payment is a manual entry.
class Payment {
  const Payment({
    required this.id,
    required this.bookingId,
    required this.kind,
    required this.amount,
    required this.mode,
    required this.reference,
    required this.receivedOn,
    required this.recordedBy,
  });

  final String id;
  final String bookingId;
  final PaymentKind kind;
  final int amount;
  final String mode;
  final String reference;
  final DateTime receivedOn;
  final String recordedBy;
}

class Rating {
  const Rating({
    required this.id,
    required this.bookingId,
    required this.bus,
    required this.driver,
    required this.overall,
    required this.createdAt,
    this.feedback = '',
  });

  final String id;
  final String bookingId;
  final int bus;
  final int driver;
  final int overall;
  final String feedback;
  final DateTime createdAt;
}

enum CancellationStatus { pending, approved, declined }

/// A customer asking to cancel. Only an admin can actually cancel.
class CancellationRequest {
  const CancellationRequest({
    required this.id,
    required this.bookingId,
    required this.requestedBy,
    required this.createdAt,
    this.reason = '',
    this.status = CancellationStatus.pending,
    this.decisionNote = '',
    this.refundAmount = 0,
  });

  final String id;
  final String bookingId;
  final String requestedBy;
  final String reason;
  final CancellationStatus status;
  final DateTime createdAt;

  /// Staff's note when they decline, shown to the customer.
  final String decisionNote;
  final int refundAmount;

  CancellationRequest copyWith(
          {CancellationStatus? status,
          String? decisionNote,
          int? refundAmount}) =>
      CancellationRequest(
        id: id,
        bookingId: bookingId,
        requestedBy: requestedBy,
        createdAt: createdAt,
        reason: reason,
        status: status ?? this.status,
        decisionNote: decisionNote ?? this.decisionNote,
        refundAmount: refundAmount ?? this.refundAmount,
      );
}
