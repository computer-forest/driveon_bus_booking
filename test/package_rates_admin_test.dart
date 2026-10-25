import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/firestore/firestore_repositories.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/features/admin/screens/package_city_editor_screen.dart';
import 'package:charter_booking_ui/features/admin/screens/package_rates_admin_screen.dart';
import 'package:charter_booking_ui/features/customer/screens/package_rates_screen.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<MockBackend> pump(WidgetTester tester, Widget home,
    {MockBackend? backend}) async {
  tester.view.physicalSize = const Size(1170, 4000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final b = backend ?? MockBackend();
  await tester.pumpWidget(ProviderScope(
    overrides: [mockBackendProvider.overrideWithValue(b)],
    child: MaterialApp(theme: AppTheme.light, home: home),
  ));
  await settle(tester);
  return b;
}

/// The list builds lazily, so its length is only known as it is scrolled.
Future<void> scrollToEnd(WidgetTester tester) async {
  final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  for (var i = 0; i < 6; i++) {
    position.jumpTo(position.maxScrollExtent);
    await settle(tester);
  }
}

Future<void> save(WidgetTester tester) async {
  await scrollToEnd(tester);
  await tester.tap(find.text('Save rates'));
  await settle(tester);
}

const _blank = PackageLocation(city: '', packages: []);

void main() {
  group('the list', () {
    testWidgets('shows every city with how many charts and destinations it has',
        (tester) async {
      await pump(tester, const PackageRatesAdminScreen());
      expect(find.text('Mumbai'), findsOneWidget);
      expect(find.text('Navi Mumbai'), findsOneWidget);
      expect(find.text('Thane'), findsOneWidget);
      expect(find.textContaining('destinations'), findsWidgets);
      expect(find.text('Note under every chart'), findsOneWidget);
    });

    testWidgets('a city opens with its destinations and rates filled in',
        (tester) async {
      await pump(tester, const PackageRatesAdminScreen());
      await tester.tap(find.text('Mumbai'));
      await settle(tester);
      expect(find.text('Karjat'), findsWidgets);
      expect(find.text('10500'), findsWidgets);
    });
  });

  group('editing a city', () {
    testWidgets('a changed rate is saved, and customers see it',
        (tester) async {
      final b = await pump(tester, const PackageRatesAdminScreen());
      await tester.tap(find.text('Mumbai'));
      await settle(tester);
      final first = find.widgetWithText(TextField, '10500').first;
      await tester.enterText(first, '11000');
      await save(tester);

      final mumbai = b.packages.items.firstWhere((p) => p.city == 'Mumbai');
      expect(mumbai.packages.first.trips.first.oneDayRate, 11000);
      expect(mumbai.id, 'mumbai', reason: 'an edit keeps the same document');
      expect(find.text('Package rates'), findsOneWidget,
          reason: 'goes back to the list');

      await tester.pumpWidget(ProviderScope(
        overrides: [mockBackendProvider.overrideWithValue(b)],
        child: MaterialApp(
            theme: AppTheme.light,
            home: PackageRatesScreen(
                location: mumbai, package: mumbai.packages.first)),
      ));
      await settle(tester);
      expect(find.text('₹11,000'), findsOneWidget);
    });

    testWidgets('a destination can be added to a chart', (tester) async {
      final b = await pump(tester, const PackageRatesAdminScreen());
      await tester.tap(find.text('Thane'));
      await settle(tester);
      final before = b.packages.items.firstWhere((p) => p.city == 'Thane').packages.last.trips.length;
      await scrollToEnd(tester);
      await tester.tap(find.text('Add a destination').last);
      await settle(tester);
      await scrollToEnd(tester);
      final fields = find.byType(TextField);
      final n = fields.evaluate().length;
      await tester.enterText(fields.at(n - 3), 'Igatpuri');
      await tester.enterText(fields.at(n - 2), '13000');
      await tester.enterText(fields.at(n - 1), '20000');
      await save(tester);
      final trips = b.packages.items.firstWhere((p) => p.city == 'Thane').packages.last.trips;
      expect(trips, hasLength(before + 1));
      expect(trips.last.destination, 'Igatpuri');
      expect(trips.last.twoDayRate, 20000);
    });

    testWidgets('switching off "only samples" is saved', (tester) async {
      final b = await pump(tester, const PackageRatesAdminScreen());
      await tester.tap(find.text('Thane'));
      await settle(tester);
      await tester.tap(find.byType(Switch).first);
      await settle(tester);
      await save(tester);
      expect(
          b.packages.items
              .firstWhere((p) => p.city == 'Thane')
              .packages
              .first
              .sampleRates,
          isFalse);
    });

    testWidgets(
        'a row with a missing rate is refused with the reason, and nothing is saved',
        (tester) async {
      final b = await pump(tester, const PackageRatesAdminScreen());
      await tester.tap(find.text('Mumbai'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, '10500').first, '');
      await save(tester);
      expect(find.textContaining('Enter the 1-day and 2-day rate'),
          findsOneWidget);
      expect(
          b.packages.items
              .firstWhere((p) => p.city == 'Mumbai')
              .packages
              .first
              .trips
              .first
              .oneDayRate,
          10500);
    });

    testWidgets('a destination listed twice is refused', (tester) async {
      await pump(tester, const PackageRatesAdminScreen());
      await tester.tap(find.text('Mumbai'));
      await settle(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'Neral / Matheran').first, 'Karjat');
      await save(tester);
      expect(find.textContaining('is listed twice'), findsOneWidget);
    });
  });

  group('adding a city', () {
    testWidgets('a new city is saved at the end with its own chart',
        (tester) async {
      final b = await pump(tester, const PackageRatesAdminScreen());
      await tester.tap(find.text('Add a city'));
      await settle(tester);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Pune');
      await tester.enterText(fields.at(1), '17–20 seater Tempo traveller');
      await tester.enterText(fields.at(2), 'Lonavala');
      await tester.enterText(fields.at(3), '9000');
      await tester.enterText(fields.at(4), '15000');
      await save(tester);
      final pune = b.packages.items.firstWhere((p) => p.city == 'Pune');
      expect(pune.id, 'pune');
      expect(pune.order, 3);
      expect(pune.packages.single.trips.single.destination, 'Lonavala');
    });

    testWidgets('a city name that already exists is refused', (tester) async {
      await pump(
          tester,
          const PackageCityEditorScreen(
              nextOrder: 3, existingCities: ['Mumbai']));
      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Pune'), ' mumbai ');
      await save(tester);
      expect(find.textContaining('already has rate charts'), findsOneWidget);
    });

    testWidgets('an empty form says what is missing', (tester) async {
      final b = await pump(tester,
          const PackageCityEditorScreen(nextOrder: 3, location: _blank));
      await save(tester);
      expect(find.text('Enter the city name.'), findsOneWidget);
      expect(b.packages.items, hasLength(3));
    });
  });

  group('the note under every chart', () {
    testWidgets('customers read the note staff saved', (tester) async {
      final b = await pump(tester, const PackageRatesAdminScreen());
      await tester.enterText(
          find.widgetWithText(TextField, AppConfig.defaultPackageNote),
          'Toll and parking are extra.');
      await settle(tester);
      await tester.tap(find.text('Save note'));
      await settle(tester);
      expect(b.config.value.packageNote, 'Toll and parking are extra.');

      final mumbai = b.packages.items.first;
      await tester.pumpWidget(ProviderScope(
        overrides: [mockBackendProvider.overrideWithValue(b)],
        child: MaterialApp(
            theme: AppTheme.light,
            home: PackageRatesScreen(
                location: mumbai, package: mumbai.packages.first)),
      ));
      await settle(tester);
      expect(find.text('Toll and parking are extra.'), findsOneWidget);
    });

    testWidgets('the default note is shown until staff change it',
        (tester) async {
      final b = MockBackend();
      final mumbai = b.packages.items.first;
      await pump(tester,
          PackageRatesScreen(location: mumbai, package: mumbai.packages.first),
          backend: b);
      expect(find.text(AppConfig.defaultPackageNote), findsOneWidget);
    });

    testWidgets('an emptied note shows nothing', (tester) async {
      final b = MockBackend()..config.value = const AppConfig(packageNote: '');
      final mumbai = b.packages.items.first;
      await pump(tester,
          PackageRatesScreen(location: mumbai, package: mumbai.packages.first),
          backend: b);
      expect(find.text(AppConfig.defaultPackageNote), findsNothing);
    });
  });

  group('storage', () {
    test('a saved city keeps its document id, so an edit never makes a copy',
        () async {
      final db = FakeFirebaseFirestore();
      await db
          .doc('packages/mumbai')
          .set({'city': 'Mumbai', 'order': 0, 'packages': []});
      final repo = FirestorePackageRepository(db, () => 'staff_919820000001');
      final existing = (await repo.watchAll().first).single;
      expect(existing.id, 'mumbai');
      await repo.save(PackageLocation(
          id: existing.id,
          order: 0,
          city: 'Mumbai',
          packages: const [
            SeaterPackage(seater: 'A', trips: [
              PackageTrip(destination: 'Karjat', oneDayRate: 1, twoDayRate: 2)
            ]),
          ]));
      final all = await repo.watchAll().first;
      expect(all, hasLength(1));
      expect(all.single.packages.single.trips.single.destination, 'Karjat');
    });

    test('a new city gets an id from its name and the staff stamp', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestorePackageRepository(db, () => 'staff_919820000001');
      await repo.save(
          const PackageLocation(city: 'Navi Mumbai', order: 4, packages: []));
      final doc = await db.doc('packages/navi-mumbai').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['updatedBy'], 'staff_919820000001');
      expect(doc.data()!['order'], 4);
    });

    test('the city id is made of letters, digits and dashes', () {
      expect(PackageLocation.idFor('  Navi Mumbai '), 'navi-mumbai');
      expect(PackageLocation.idFor('Pune / Lonavala'), 'pune-lonavala');
      expect(PackageLocation.idFor('???'), '');
    });
  });
}
