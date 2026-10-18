import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/firestore/firestore_repositories.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/data/repositories/repositories.dart';
import 'package:charter_booking_ui/features/admin/screens/reallocation_picker_screen.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Booking booking(MockBackend b, String id) => b.bookings.items.firstWhere((e) => e.id == id);

void main() {
  group('the repositories', () {
    test('the server is sent the reason and the revised fare, and no fare when it is not changing', () async {
      final calls = <Map<String, dynamic>>[];
      final repo = FirestoreBookingRepository(FakeFirebaseFirestore(), () => 'staff_1', (n, d) async {
        calls.add(d);
        return {};
      }, isAdmin: true);
      await repo.reallocate('bk', 'bus-2', reason: 'Mechanical issue', revisedFare: 20000);
      await repo.reallocate('bk', 'bus-3');
      expect(calls[0], {'bookingId': 'bk', 'action': 'reallocate', 'newBusId': 'bus-2', 'reason': 'Mechanical issue', 'revisedFare': 20000});
      expect(calls[1].containsKey('revisedFare'), isFalse);
      expect(calls[1]['reason'], '');
    });

    test('demo mode applies the new fare and refuses one below what was paid', () async {
      final b = MockBackend();
      final repo = MockBookingRepository(b);
      final paid = booking(b, 'bk-0491').amountPaid;
      await expectLater(
        repo.reallocate('bk-0491', 'bus-1120', revisedFare: paid - 1),
        throwsA(isA<BookingException>().having((e) => e.message, 'm', contains('already paid'))),
      );
      expect(booking(b, 'bk-0491').busId, 'bus-7781', reason: 'nothing moved');

      await repo.reallocate('bk-0491', 'bus-1120', reason: 'Vendor needs the bus elsewhere', revisedFare: 21000);
      expect(booking(b, 'bk-0491').busId, 'bus-1120');
      expect(booking(b, 'bk-0491').totalFare, 21000);
    });

    test('without a revised fare the fare is untouched', () async {
      final b = MockBackend();
      final fare = booking(b, 'bk-0491').totalFare;
      await MockBookingRepository(b).reallocate('bk-0491', 'bus-1120');
      expect(booking(b, 'bk-0491').totalFare, fare);
    });
  });

  group('the screen', () {
    late MockBackend backend;
    ReallocationChoice? popped;

    Future<void> open(WidgetTester tester, {int fare = 18000, int paid = 4500}) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      backend = MockBackend();
      popped = null;
      final b = booking(backend, 'bk-0491');
      await tester.pumpWidget(ProviderScope(
        overrides: [mockBackendProvider.overrideWithValue(backend)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    popped = await Navigator.of(context).push<ReallocationChoice>(MaterialPageRoute(
                      builder: (_) => ReallocationPickerScreen(
                        currentBusId: b.busId,
                        start: b.start,
                        end: b.end,
                        currentFare: fare,
                        amountPaid: paid,
                      ),
                    ));
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    Future<void> pickBusAndReason(WidgetTester tester) async {
      await tester.tap(find.text('MH-12-AK-1120'));
      await settle(tester);
      await tester.tap(find.text('Mechanical issue'));
      await settle(tester);
    }

    Future<void> confirm(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Confirm reallocation'));
      await settle(tester);
      await tester.tap(find.text('Confirm reallocation'));
      await settle(tester);
    }

    testWidgets('hands back the bus and the reason; no fare when the cost is not changing', (tester) async {
      await open(tester);
      await pickBusAndReason(tester);
      await confirm(tester);
      expect(popped!.bus.regNumber, 'MH-12-AK-1120');
      expect(popped!.reason, 'Mechanical issue');
      expect(popped!.revisedFare, isNull);
    });

    testWidgets('the revised fare box starts with the current fare and is handed back when the cost changes', (tester) async {
      await open(tester);
      await pickBusAndReason(tester);
      await tester.tap(find.byType(Switch));
      await settle(tester);
      expect(tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text, '18000');
      await tester.enterText(find.byType(TextFormField), '21,500');
      await settle(tester);
      await confirm(tester);
      expect(popped!.revisedFare, 21500);
    });

    testWidgets('a fare below what was paid is explained and cannot be confirmed', (tester) async {
      await open(tester, paid: 4500);
      await pickBusAndReason(tester);
      await tester.tap(find.byType(Switch));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField), '4000');
      await settle(tester);
      await tester.ensureVisible(find.textContaining('already paid'));
      expect(find.textContaining('cannot be less than the ₹4,500 already paid'), findsOneWidget);
      await tester.ensureVisible(find.text('Confirm reallocation'));
      await settle(tester);
      await tester.tap(find.text('Confirm reallocation'), warnIfMissed: false);
      await settle(tester);
      expect(popped, isNull);
      expect(find.text('Reallocate bus'), findsOneWidget);
    });

    testWidgets('an empty or zero fare is refused while the cost switch is on', (tester) async {
      await open(tester);
      await pickBusAndReason(tester);
      await tester.tap(find.byType(Switch));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField), '0');
      await settle(tester);
      await tester.ensureVisible(find.text('Confirm reallocation'));
      await tester.tap(find.text('Confirm reallocation'), warnIfMissed: false);
      await settle(tester);
      expect(popped, isNull);
    });

    testWidgets('turning the cost switch off again drops the fare', (tester) async {
      await open(tester);
      await pickBusAndReason(tester);
      await tester.tap(find.byType(Switch));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField), '30000');
      await tester.tap(find.byType(Switch));
      await settle(tester);
      await confirm(tester);
      expect(popped!.revisedFare, isNull);
    });
  });
}
