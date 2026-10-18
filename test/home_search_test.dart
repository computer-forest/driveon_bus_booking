import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/features/customer/screens/home_search_screen.dart';
import 'package:charter_booking_ui/features/customer/screens/results_screen.dart';

const customer = AppUser(id: 'cust_919820011223', role: UserRole.customer, name: 'Rohan', phone: '98200 11223', onboarded: true);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<MockBackend> pump(WidgetTester tester, {AppConfig? config, bool noPackages = false}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final backend = MockBackend()..user.value = customer;
  if (config != null) backend.config.value = config;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      mockBackendProvider.overrideWithValue(backend),
      if (noPackages) packagesProvider.overrideWith((ref) => Stream.value(const <PackageLocation>[])),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const HomeSearchScreen()),
  ));
  await settle(tester);
  return backend;
}

/// Scrolls until [f] is built, then until it is comfortably on screen.
Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(f);
  await settle(tester);
}

PrimaryButtonProbe searchButton(WidgetTester tester) => PrimaryButtonProbe(tester);

class PrimaryButtonProbe {
  PrimaryButtonProbe(this.tester);
  final WidgetTester tester;

  /// The button is enabled when its label can be tapped through to ResultsScreen.
  Future<bool> opensResults() async {
    await scrollTo(tester, find.text('Search buses'));
    await tester.tap(find.text('Search buses'), warnIfMissed: false);
    await settle(tester);
    return find.byType(ResultsScreen).evaluate().isNotEmpty;
  }
}

/// Opens the picker from the empty field (found by its hint) and picks [place].
Future<void> choose(WidgetTester tester, String hint, String place) async {
  await scrollTo(tester, find.text(hint));
  await tester.tap(find.text(hint), warnIfMissed: false); // the hint is painted by the field, which takes the tap
  await settle(tester);
  await tester.tap(find.text(place).first);
  await settle(tester);
}

void main() {
  testWidgets('nothing is assumed: no pickup or drop is pre-filled, and search is held back with a reason', (tester) async {
    await pump(tester);
    expect(find.textContaining('Mahabaleshwar'), findsNothing);
    expect(find.text('Thane West'), findsNothing);
    expect(find.text('Choose where to start'), findsOneWidget);
    expect(find.text('Choose where to go'), findsOneWidget);
    await scrollTo(tester, find.text('Search buses'));
    expect(find.text('Choose a pickup and a drop to search.'), findsOneWidget);
    expect(await searchButton(tester).opensResults(), isFalse);
  });

  testWidgets('with both places chosen from the list, search opens the results', (tester) async {
    await pump(tester);
    await choose(tester, 'Choose where to start', 'Thane West');
    expect(find.textContaining('Choose a pickup and a drop'), findsOneWidget, reason: 'still waiting for the drop');
    await choose(tester, 'Choose where to go', 'Main Market');
    await scrollTo(tester, find.text('Search buses'));
    expect(find.textContaining('Choose a pickup and a drop'), findsNothing);
    expect(await searchButton(tester).opensResults(), isTrue);
  });

  testWidgets('seat sizes come from the staff configuration, in order, and none is chosen to begin with', (tester) async {
    await pump(tester, config: const AppConfig(capacities: [52, 12, 30]));
    await scrollTo(tester, find.text('Preferred capacity (optional)'));
    final chips = ['12', '30', '52'];
    for (final c in chips) {
      expect(find.text(c), findsOneWidget);
    }
    expect(find.text('17'), findsNothing);
    expect(find.text('40'), findsNothing);
    expect(tester.getTopLeft(find.text('12')).dx, lessThan(tester.getTopLeft(find.text('30')).dx));
    expect(tester.getTopLeft(find.text('30')).dx, lessThan(tester.getTopLeft(find.text('52')).dx));
  });

  testWidgets('tapping the chosen size again goes back to any size, and the choice reaches the search', (tester) async {
    await pump(tester);
    await choose(tester, 'Choose where to start', 'Thane West');
    await choose(tester, 'Choose where to go', 'Main Market');
    await scrollTo(tester, find.text('Preferred capacity (optional)'));
    await tester.tap(find.text('20'));
    await settle(tester);
    await tester.tap(find.text('20')); // off again
    await settle(tester);
    await tester.tap(find.text('35'));
    await settle(tester);
    await scrollTo(tester, find.text('Search buses'));
    await tester.tap(find.text('Search buses'));
    await settle(tester);
    final results = tester.widget<ResultsScreen>(find.byType(ResultsScreen));
    expect(results.criteria.capacity, 35);
    expect(results.criteria.summary, startsWith('Thane West → Main Market'));
  });

  testWidgets('the outstation card names the cities that really have packages', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Outstation'));
    await settle(tester);
    expect(find.text('Fixed return rates from Mumbai, Navi Mumbai and Thane'), findsOneWidget);
  });

  testWidgets('with no packages in the database the outstation card is not shown at all', (tester) async {
    await pump(tester, noPackages: true);
    await tester.tap(find.text('Outstation'));
    await settle(tester);
    expect(find.text('Popular outstation packages'), findsNothing);
  });
}
