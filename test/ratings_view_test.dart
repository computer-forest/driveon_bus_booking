import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/data/mock_data.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/rating_stats.dart';
import 'package:charter_booking_ui/data/repositories/firestore/firestore_repositories.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/features/admin/screens/ratings_screen.dart';

Rating rating(String id, String bookingId, int bus, int driver, int overall, {String feedback = '', DateTime? at}) =>
    Rating(id: id, bookingId: bookingId, bus: bus, driver: driver, overall: overall, feedback: feedback, createdAt: at ?? DateTime(2026, 9, 14, 9));

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  group('the averages', () {
    test('nothing rated gives zeros, not a divide by zero', () {
      expect(ratingStats(const []).count, 0);
      expect(ratingStats(const []).overall, 0);
    });

    test('averages are worked out per score', () {
      final s = ratingStats([rating('a', 'b1', 5, 4, 5), rating('b', 'b2', 3, 2, 4), rating('c', 'b3', 4, 3, 3)]);
      expect(s.count, 3);
      expect(s.bus, closeTo(4.0, 1e-9));
      expect(s.driver, closeTo(3.0, 1e-9));
      expect(s.overall, closeTo(4.0, 1e-9));
    });

    test('by bus: grouped through the booking, lowest first, ratings for a missing booking left out of the grouping', () {
      final bookings = MockData.bookings;
      final onA = bookings.firstWhere((b) => b.id == 'bk-0472'); // bus-7781
      final onB = bookings.firstWhere((b) => b.id == 'bk-0473'); // bus-9902
      final result = ratingsByBus([
        rating('1', onA.id, 5, 5, 5),
        rating('2', onB.id, 2, 2, 2),
        rating('3', onB.id, 3, 3, 4),
        rating('4', 'gone', 1, 1, 1),
      ], bookings);
      expect(result.map((r) => r.busReg), [onB.busReg, onA.busReg]);
      expect(result.first.stats.count, 2);
      expect(result.first.stats.overall, closeTo(3.0, 1e-9));
    });
  });

  group('the data', () {
    test('Firestore ratings come back newest first with their text', () async {
      final db = FakeFirebaseFirestore();
      await db.doc('ratings/old').set({'bookingId': 'b', 'bus': 4, 'driver': 4, 'overall': 4, 'feedback': 'Fine', 'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1))});
      await db.doc('ratings/new').set({'bookingId': 'b', 'bus': 1, 'driver': 2, 'overall': 1, 'feedback': 'Late and dirty', 'createdAt': Timestamp.fromDate(DateTime(2026, 9, 2))});
      await db.doc('ratings/odd').set({'bookingId': 'b', 'bus': 'x', 'feedback': 5, 'createdAt': Timestamp.fromDate(DateTime(2026, 8, 1))});
      final all = await FirestoreRatingRepository(db, () => 'staff_1').watchAll().first;
      expect(all.map((r) => r.id), ['new', 'old', 'odd']);
      expect(all.first.feedback, 'Late and dirty');
      expect(all.first.createdAt, DateTime(2026, 9, 2));
      expect(all.last.bus, 0, reason: 'a damaged score is read as 0, not a crash');
      expect(all.last.feedback, '');
    });
  });

  group('the screen', () {
    Future<MockBackend> pump(WidgetTester tester, List<Rating> ratings) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final backend = MockBackend();
      for (final r in ratings) {
        backend.ratings.add(r);
      }
      await tester.pumpWidget(ProviderScope(
        overrides: [mockBackendProvider.overrideWithValue(backend)],
        child: MaterialApp(theme: AppTheme.light, home: const RatingsScreen()),
      ));
      await settle(tester);
      return backend;
    }

    testWidgets('with no ratings yet it says so', (tester) async {
      await pump(tester, const []);
      expect(find.textContaining('No ratings yet'), findsOneWidget);
    });

    testWidgets('shows the averages, the buses lowest first, and each rating with its trip and comment', (tester) async {
      await pump(tester, [
        rating('1', 'bk-0472', 5, 5, 5, feedback: 'Smooth ride'),
        rating('2', 'bk-0473', 2, 3, 2, feedback: 'Bus was dirty'),
      ]);
      expect(find.text('3.5'), findsWidgets); // overall average
      expect(find.text('From 2 ratings, out of 5.'), findsOneWidget);
      expect(find.text('By bus, lowest first'), findsOneWidget);
      expect(find.text('CB-20260914-0473'), findsOneWidget);
      expect(find.text('"Bus was dirty"'), findsOneWidget);
      expect(find.text('Mumbai → Lonavala · MH-04-CT-9902'), findsOneWidget);
      expect(find.text('Bus 2 · Driver 3'), findsOneWidget);
      final worst = tester.getTopLeft(find.text('MH-04-CT-9902').first).dy;
      final best = tester.getTopLeft(find.text('MH-04-BT-7781').first).dy;
      expect(worst, lessThan(best), reason: 'the buses that need attention come first');
    });

    testWidgets('the low-ratings filter keeps only one and two stars', (tester) async {
      await pump(tester, [
        rating('1', 'bk-0472', 5, 5, 5, feedback: 'Smooth ride'),
        rating('2', 'bk-0473', 2, 3, 2, feedback: 'Bus was dirty'),
      ]);
      await tester.tap(find.text('1 or 2 stars only'));
      await settle(tester);
      expect(find.text('"Smooth ride"'), findsNothing);
      expect(find.text('"Bus was dirty"'), findsOneWidget);
    });

    testWidgets('a filter that matches nothing says so', (tester) async {
      await pump(tester, [rating('1', 'bk-0472', 5, 5, 5)]);
      await tester.tap(find.text('1 or 2 stars only'));
      await settle(tester);
      expect(find.text('No low ratings. Good.'), findsOneWidget);
    });

    testWidgets("a rating whose booking is gone still appears, without a trip", (tester) async {
      await pump(tester, [rating('1', 'deleted-booking', 4, 4, 4, feedback: 'ok')]);
      expect(find.text('A booking'), findsOneWidget);
      expect(find.text('"ok"'), findsOneWidget);
    });
  });
}
