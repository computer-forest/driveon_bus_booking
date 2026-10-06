import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/data/mock_data.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/firestore/firestore_codec.dart';
import 'package:charter_booking_ui/data/repositories/firestore/firestore_repositories.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/data/repositories/repositories.dart';
import 'package:charter_booking_ui/features/admin/screens/admin_dashboard_screen.dart';
import 'package:charter_booking_ui/features/admin/screens/admin_notifications_screen.dart';
import 'package:charter_booking_ui/features/admin/screens/cancellation_requests_screen.dart';
import 'package:charter_booking_ui/features/admin/screens/reports_screen.dart';
import 'package:charter_booking_ui/features/customer/screens/booking_detail_screen.dart';
import 'package:charter_booking_ui/features/customer/screens/delete_account_screen.dart';
import 'package:charter_booking_ui/features/customer/screens/notifications_screen.dart';
import 'package:charter_booking_ui/features/notifications/push_service.dart';

// ---------------------------------------------------------------- push --

class FakeTokenSource implements PushTokenSource {
  bool allowed = true;
  String? current = 'tok-1';
  bool deleted = false;
  final refreshes = StreamController<String>.broadcast();

  @override
  Future<bool> requestPermission() async => allowed;

  @override
  Future<String?> token() async => current;

  @override
  Stream<String> get onRefresh => refreshes.stream;

  @override
  Future<void> deleteToken() async => deleted = true;
}

// ------------------------------------------------------------- widgets --

AppUser staffUser() => const AppUser(id: 'staff_919820000001', role: UserRole.admin, name: 'Priya', onboarded: true);
AppUser customerUser() => const AppUser(
    id: 'cust_919820011223', role: UserRole.customer, name: 'Rohan Deshmukh', phone: '98200 11223', onboarded: true);

Future<MockBackend> pumpApp(WidgetTester tester, Widget screen, {AppUser? user, MockBackend? backend}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final b = backend ?? MockBackend();
  if (user != null) b.user.value = user;
  await tester.pumpWidget(ProviderScope(
    overrides: [mockBackendProvider.overrideWithValue(b)],
    child: MaterialApp(theme: AppTheme.light, home: screen),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
  return b;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> scrollTo(WidgetTester tester, String text) =>
    tester.scrollUntilVisible(find.text(text), 300, scrollable: find.byType(Scrollable).first);

Booking bookingOf(MockBackend b, String id) => b.bookings.items.firstWhere((e) => e.id == id);

void main() {
  group('push registration', () {
    late FakeFirebaseFirestore db;
    late FakeTokenSource source;
    late DevicePushService push;

    setUp(() {
      db = FakeFirebaseFirestore();
      source = FakeTokenSource();
      push = DevicePushService(db, source, platform: () => 'android');
    });

    test('a signed-in person gets this phone registered under their id', () async {
      await push.register('cust_1');
      final doc = await db.doc('users/cust_1/devices/tok-1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['platform'], 'android');
      expect(doc.data()!['updatedAt'], isNotNull);
    });

    test('asking again for the same person does nothing extra', () async {
      await push.register('cust_1');
      source.current = 'tok-2';
      await push.register('cust_1');
      expect((await db.collection('users/cust_1/devices').get()).docs.map((d) => d.id), ['tok-1']);
    });

    test('someone refusing notifications is simply not registered', () async {
      source.allowed = false;
      await push.register('cust_1');
      expect((await db.collection('users/cust_1/devices').get()).docs, isEmpty);
    });

    test('a phone that cannot produce a token is skipped without an error', () async {
      source.current = null;
      await push.register('cust_1');
      expect((await db.collection('users/cust_1/devices').get()).docs, isEmpty);
    });

    test('a refreshed token replaces the old one', () async {
      await push.register('cust_1');
      source.refreshes.add('tok-9');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect((await db.collection('users/cust_1/devices').get()).docs.map((d) => d.id), ['tok-9']);
    });

    test('signing out forgets this phone', () async {
      await push.register('cust_1');
      await push.unregister();
      expect((await db.collection('users/cust_1/devices').get()).docs, isEmpty);
      expect(source.deleted, isTrue);
    });

    test('a different person on the same phone takes it over', () async {
      await push.register('cust_1');
      await push.register('cust_2');
      expect((await db.collection('users/cust_1/devices').get()).docs, isEmpty);
      expect((await db.collection('users/cust_2/devices').get()).docs.map((d) => d.id), ['tok-1']);
    });
  });

  group('inbox and cancellations on Firestore', () {
    late FakeFirebaseFirestore db;
    String? uid = 'cust_1';

    setUp(() {
      db = FakeFirebaseFirestore();
      uid = 'cust_1';
    });

    test('the inbox is the signed-in person\'s own, newest first, with the booking link and tone', () async {
      await db.doc('notifications/a').set({'userId': 'cust_1', 'title': 'Older', 'body': 'b', 'tone': 'info', 'read': true, 'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1))});
      await db.doc('notifications/b').set({'userId': 'cust_1', 'title': 'Newer', 'body': 'b', 'tone': 'urgent', 'read': false, 'bookingId': 'bk-1', 'createdAt': Timestamp.fromDate(DateTime(2026, 10, 2))});
      await db.doc('notifications/c').set({'userId': 'cust_2', 'title': 'Someone else', 'body': 'b', 'createdAt': Timestamp.fromDate(DateTime(2026, 10, 3))});

      final inbox = await FirestoreNotificationRepository(db, () => uid).watchAll().first;

      expect(inbox.map((n) => n.title), ['Newer', 'Older']);
      expect(inbox.first.tone, NotificationTone.urgent);
      expect(inbox.first.bookingId, 'bk-1');
      expect(inbox.first.read, isFalse);
    });

    test('marking one read updates only that one', () async {
      await db.doc('notifications/a').set({'userId': 'cust_1', 'title': 'A', 'body': 'b', 'read': false, 'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1))});
      await db.doc('notifications/b').set({'userId': 'cust_1', 'title': 'B', 'body': 'b', 'read': false, 'createdAt': Timestamp.fromDate(DateTime(2026, 10, 2))});
      final repo = FirestoreNotificationRepository(db, () => uid);
      await repo.markRead('a');
      final inbox = {for (final n in await repo.watchAll().first) n.id: n};
      expect(inbox['a']!.read, isTrue);
      expect(inbox['b']!.read, isFalse);
    });

    test('signed out there is no inbox', () async {
      uid = null;
      expect(await FirestoreNotificationRepository(db, () => uid).watchAll().first, isEmpty);
    });

    test('a customer sees only their own cancellation requests; staff see all, with the decision', () async {
      await db.doc('cancellations/r1').set({'bookingId': 'b1', 'requestedBy': 'cust_1', 'reason': 'x', 'status': 'declined', 'decisionNote': 'Driver already scheduled', 'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1))});
      await db.doc('cancellations/r2').set({'bookingId': 'b2', 'requestedBy': 'cust_2', 'reason': 'y', 'status': 'approved', 'refundAmount': 3000, 'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1))});

      final mine = await FirestoreCancellationRepository(db, () => uid).watchAll().first;
      expect(mine.map((r) => r.id), ['r1']);
      expect(mine.single.status, CancellationStatus.declined);
      expect(mine.single.decisionNote, 'Driver already scheduled');

      uid = 'staff_1';
      final all = await FirestoreCancellationRepository(db, () => uid, isAdmin: true).watchAll().first;
      expect(all.map((r) => r.id), unorderedEquals(['r1', 'r2']));
      expect(all.firstWhere((r) => r.id == 'r2').refundAmount, 3000);
    });

    test('approving with a refund and declining send the right calls', () async {
      final calls = <(String, Map<String, dynamic>)>[];
      Future<Map<String, dynamic>> call(String n, Map<String, dynamic> d) async {
        calls.add((n, d));
        return {};
      }

      final repo = FirestoreBookingRepository(db, () => 'staff_1', call, isAdmin: true);
      await repo.cancel('bk', reason: 'Customer requested', refundAmount: 3000, mode: 'UPI', reference: 'R1', requestId: 'req');
      await repo.cancel('bk2');
      await repo.declineCancellation('bk', requestId: 'req', note: 'Not possible');

      expect(calls[0].$2, {
        'bookingId': 'bk', 'action': 'cancel', 'reason': 'Customer requested', 'refundAmount': 3000,
        'mode': 'UPI', 'reference': 'R1', 'requestId': 'req',
      });
      expect(calls[1].$2.containsKey('requestId'), isFalse);
      expect(calls[1].$2['refundAmount'], 0);
      expect(calls[2].$2, {'bookingId': 'bk', 'action': 'declineCancellation', 'requestId': 'req', 'note': 'Not possible'});
    });

    test('a refund larger than what was paid is reported as the server worded it', () async {
      Future<Map<String, dynamic>> call(String n, Map<String, dynamic> d) =>
          throw FirebaseFunctionsException(message: 'The refund cannot be more than what was paid (₹4500).', code: 'failed-precondition');
      await expectLater(
        FirestoreBookingRepository(db, () => 'staff_1', call, isAdmin: true).cancel('bk', refundAmount: 9999),
        throwsA(isA<BookingException>().having((e) => e.message, 'm', contains('₹4500'))),
      );
    });

    test('every payment can be read for the reports, and search misses become times', () async {
      await db.doc('payments/p1').set({'bookingId': 'a', 'kind': 'advance', 'amount': 100, 'receivedOn': Timestamp.fromDate(DateTime(2026, 10, 1))});
      await db.doc('payments/p2').set({'bookingId': 'b', 'kind': 'refund', 'amount': 50, 'receivedOn': Timestamp.fromDate(DateTime(2026, 10, 2))});
      expect((await FirestorePaymentRepository(db, () => uid).watchAll().first).map((p) => p.kind), unorderedEquals([PaymentKind.advance, PaymentKind.refund]));
      await db.doc('searchMisses/m1').set({'at': Timestamp.fromDate(DateTime(2026, 10, 1, 9))});
      expect(await FirestoreReportRepository(db, () => uid).watchSearchMisses().first, [DateTime(2026, 10, 1, 9)]);
    });

    test('a booking with refund and timestamps reads back', () {
      final b = Codec.bookingFromMap('x', {
        'reference': 'CB-1', 'start': DateTime(2026, 10, 1, 9), 'end': DateTime(2026, 10, 1, 15), 'stage': 'cancelled',
        'amountPaid': 1500, 'refundedAmount': 3000, 'createdAt': DateTime(2026, 9, 30), 'confirmedAt': DateTime(2026, 9, 30, 1),
      });
      expect(b.stage, BookingStage.cancelled);
      expect(b.refundedAmount, 3000);
      expect(b.createdAt, DateTime(2026, 9, 30));
      expect(b.confirmedAt, DateTime(2026, 9, 30, 1));
    });
  });

  group('demo-mode cancellation rules mirror the server', () {
    test('approval refunds, cancels, frees the bus and settles the request; a second decision is refused', () async {
      final b = MockBackend();
      final repo = MockBookingRepository(b);
      b.cancellations.add(CancellationRequest(id: 'req', bookingId: 'bk-0491', requestedBy: 'cust', createdAt: MockData.now, reason: 'Plans changed'));

      await expectLater(repo.cancel('bk-0491', refundAmount: 99999), throwsA(isA<BookingException>().having((e) => e.message, 'm', contains('more than what was paid'))));
      await repo.cancel('bk-0491', reason: 'Customer requested', refundAmount: 3000, requestId: 'req');

      final booking = bookingOf(b, 'bk-0491');
      expect(booking.stage, BookingStage.cancelled);
      expect(booking.amountPaid, 1500);
      expect(booking.refundedAmount, 3000);
      expect(b.payments.items.where((p) => p.bookingId == 'bk-0491' && p.kind == PaymentKind.refund).single.amount, 3000);
      expect(b.cancellations.items.single.status, CancellationStatus.approved);
      expect(b.cancellations.items.single.refundAmount, 3000);
      await expectLater(repo.declineCancellation('bk-0491', requestId: 'req'), throwsA(isA<BookingException>()));
    });

    test('declining keeps the booking and records the note', () async {
      final b = MockBackend();
      final repo = MockBookingRepository(b);
      b.cancellations.add(CancellationRequest(id: 'req', bookingId: 'bk-0491', requestedBy: 'cust', createdAt: MockData.now));
      await repo.declineCancellation('bk-0491', requestId: 'req', note: 'Driver already scheduled');
      expect(bookingOf(b, 'bk-0491').stage, BookingStage.confirmed);
      expect(b.cancellations.items.single.status, CancellationStatus.declined);
      expect(b.cancellations.items.single.decisionNote, 'Driver already scheduled');
    });
  });

  group('screens', () {
    testWidgets('staff see a request waiting, open it, approve it with a refund, and the booking is cancelled', (tester) async {
      final b = MockBackend();
      b.cancellations.add(CancellationRequest(id: 'req', bookingId: 'bk-0491', requestedBy: 'cust', createdAt: MockData.now, reason: 'Plans changed'));
      await pumpApp(tester, const CancellationRequestsScreen(), user: staffUser(), backend: b);

      expect(find.text('Needs a decision'), findsOneWidget);
      expect(find.text('"Plans changed"'), findsOneWidget);
      await tester.tap(find.text('CB-20260916-0491'));
      await settle(tester);

      expect(find.text('Neha Sawant asked to cancel'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, '').first, '3000');
      await settle(tester);
      await tester.tap(find.text('Customer requested'));
      await settle(tester);
      await scrollTo(tester, 'Approve and cancel booking');
      await tester.tap(find.text('Approve and cancel booking'));
      await settle(tester);

      final booking = bookingOf(b, 'bk-0491');
      expect(booking.stage, BookingStage.cancelled);
      expect(booking.refundedAmount, 3000);
      expect(find.text('Needs a decision'), findsNothing);
      expect(find.text('Cancelled'), findsWidgets);
    });

    testWidgets('a refund bigger than what was paid is blocked on the form', (tester) async {
      final b = MockBackend();
      b.cancellations.add(CancellationRequest(id: 'req', bookingId: 'bk-0491', requestedBy: 'cust', createdAt: MockData.now));
      await pumpApp(tester, const CancellationRequestsScreen(), user: staffUser(), backend: b);
      await tester.tap(find.text('CB-20260916-0491'));
      await settle(tester);
      await tester.tap(find.byType(Switch));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, '').first, '9000');
      await settle(tester);

      expect(find.textContaining('more than was paid'), findsOneWidget);
      await scrollTo(tester, 'Approve and cancel booking');
      final approve = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Approve and cancel booking'));
      expect(approve.onPressed, isNull);
    });

    testWidgets('staff can decline with a note, and the booking stays', (tester) async {
      final b = MockBackend();
      b.cancellations.add(CancellationRequest(id: 'req', bookingId: 'bk-0491', requestedBy: 'cust', createdAt: MockData.now));
      await pumpApp(tester, const CancellationRequestsScreen(), user: staffUser(), backend: b);
      await tester.tap(find.text('CB-20260916-0491'));
      await settle(tester);
      await scrollTo(tester, 'Decline request');
      await tester.tap(find.text('Decline request'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'Driver already scheduled');
      await tester.tap(find.text('Decline'));
      await settle(tester);

      expect(bookingOf(b, 'bk-0491').stage, BookingStage.confirmed);
      expect(b.cancellations.items.single.status, CancellationStatus.declined);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('Note: Driver already scheduled'), findsOneWidget);
    });

    testWidgets('the dashboard shows how many cancellation requests are waiting and the unread bell', (tester) async {
      final b = MockBackend();
      b.cancellations.add(CancellationRequest(id: 'req', bookingId: 'bk-0491', requestedBy: 'cust', createdAt: MockData.now));
      await pumpApp(tester, const AdminDashboardScreen(), user: staffUser(), backend: b);
      expect(find.text('Cancellation requests (1 waiting)'), findsOneWidget);
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.text('Operations console'), findsOneWidget);
    });

    testWidgets('a customer with a pending request cannot send another, and sees a declined one explained', (tester) async {
      final b = MockBackend();
      final booking = bookingOf(b, 'bk-0472');
      b.cancellations.add(CancellationRequest(id: 'req', bookingId: booking.id, requestedBy: 'cust_919820011223', createdAt: MockData.now));
      await pumpApp(tester, BookingDetailScreen(booking: booking), user: customerUser(), backend: b);
      await tester.scrollUntilVisible(find.text('Cancellation requested — awaiting our team'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Request cancellation'), findsNothing);

      b.cancellations.replaceAll([b.cancellations.items.single.copyWith(status: CancellationStatus.declined, decisionNote: 'Driver already scheduled.')]);
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Request cancellation'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Your cancellation request was declined. Driver already scheduled.'), findsOneWidget);
    });

    testWidgets('a settled booking is rated, not cancelled; a cancelled one says so', (tester) async {
      final b = MockBackend();
      final done = bookingOf(b, 'bk-0473').copyWith(stage: BookingStage.settled);
      b.bookings.upsert((e) => e.id == done.id, done); // the screen shows the live copy
      await pumpApp(tester, BookingDetailScreen(booking: done), user: customerUser(), backend: b);
      await tester.scrollUntilVisible(find.text('Rate this trip'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Request cancellation'), findsNothing);

      final cancelled = done.copyWith(stage: BookingStage.cancelled);
      b.bookings.upsert((e) => e.id == cancelled.id, cancelled);
      await settle(tester);
      await tester.scrollUntilVisible(find.text('This booking was cancelled.'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Rate this trip'), findsNothing);
      expect(find.text('Request cancellation'), findsNothing);
    });

    testWidgets('the notification inbox lists entries, marks one read on tap and opens its booking', (tester) async {
      final b = MockBackend();
      b.notifications.upsert((e) => e.id == 'ntf-1', b.notifications.items.first.copyWith(read: false));
      await pumpApp(tester, const NotificationsScreen(), user: customerUser(), backend: b);
      expect(find.text('Booking confirmed'), findsOneWidget);

      await tester.tap(find.text('Booking confirmed'));
      await settle(tester);
      expect(b.notifications.items.firstWhere((n) => n.id == 'ntf-1').read, isTrue);
    });

    testWidgets("staff's inbox opens", (tester) async {
      await pumpApp(tester, const AdminNotificationsScreen(), user: staffUser());
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('reports follow the period chosen, from real bookings', (tester) async {
      await pumpApp(tester, const ReportsScreen(), user: staffUser());
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Outstanding payments'), findsOneWidget);
      await tester.tap(find.text('This month'));
      await settle(tester);
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Failed searches'), findsOneWidget);
      // the old placeholder figures are gone
      expect(find.text('₹86,200'), findsNothing);
    });

    testWidgets('deleting an account that is refused explains why and keeps the person signed in', (tester) async {
      final b = MockBackend();
      b.user.value = customerUser();
      await pumpApp(tester, const DeleteAccountScreen(), backend: b);
      expect(find.text('Delete account'), findsWidgets);
    });
  });
}
