import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/data/mock_data.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/data/repositories/repositories.dart';
import 'package:charter_booking_ui/features/customer/screens/rating_screen.dart';

class _FailingRatings implements RatingRepository {
  @override
  Stream<List<Rating>> watchAll() => Stream.value(const []);

  @override
  Future<void> submit(Rating rating) => throw const BookingException('No internet connection. Check your connection and try again.');
}

Future<void> pump(WidgetTester tester, Booking booking, {RatingRepository? ratings}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      mockBackendProvider.overrideWithValue(MockBackend()),
      if (ratings != null) ratingRepositoryProvider.overrideWithValue(ratings),
    ],
    child: MaterialApp(theme: AppTheme.light, home: RatingScreen(booking: booking)),
  ));
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> rateEverything(WidgetTester tester) async {
  for (var row = 0; row < 3; row++) {
    final stars = find.byIcon(Icons.star_outline_rounded);
    await tester.tap(stars.at(4)); // five stars on the first still-empty row
    await tester.pump();
  }
}

void main() {
  testWidgets("the header names the customer's own trip and reference, not a sample", (tester) async {
    final booking = MockData.bookings.firstWhere((b) => b.id == 'bk-0490');
    await pump(tester, booking);
    expect(find.text('${booking.route} · ${booking.reference}'), findsOneWidget);
    expect(find.textContaining('CB-20260914-0472'), findsNothing);
    expect(find.textContaining('Mahabaleshwar'), findsNothing);
  });

  testWidgets('a different booking shows its own details', (tester) async {
    final booking = MockData.bookings.firstWhere((b) => b.id == 'bk-0473');
    await pump(tester, booking);
    expect(find.text('Mumbai → Lonavala · CB-20260914-0473'), findsOneWidget);
  });

  testWidgets('a rating that cannot be saved says so and stays on the form', (tester) async {
    final booking = MockData.bookings.firstWhere((b) => b.id == 'bk-0490');
    await pump(tester, booking, ratings: _FailingRatings());
    await rateEverything(tester);
    await tester.scrollUntilVisible(find.text('Submit rating'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Submit rating'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.textContaining('No internet connection'), findsOneWidget);
    expect(find.text('Rate your trip'), findsOneWidget);
  });
}
