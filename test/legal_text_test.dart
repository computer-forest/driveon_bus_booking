import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/data/legal_defaults.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/firestore/firestore_repositories.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/features/admin/screens/legal_editor_screen.dart';
import 'package:charter_booking_ui/features/customer/screens/terms_privacy_screen.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<MockContentRepository> pump(WidgetTester tester, Widget screen,
    {MockContentRepository? content}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final repo = content ?? MockContentRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [contentRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(theme: AppTheme.light, home: screen),
  ));
  await settle(tester);
  return repo;
}

void main() {
  group('stored in Firestore', () {
    test('nothing there means null, not an empty document', () async {
      final repo =
          FirestoreContentRepository(FakeFirebaseFirestore(), () => 'staff_1');
      expect(await repo.watchLegal(LegalKind.terms).first, isNull);
    });

    test(
        'saving writes the sections to legal/terms with who and when, and reads them back in order',
        () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreContentRepository(db, () => 'staff_919820000001');
      await repo.saveLegal(LegalKind.terms, const [
        LegalSection(heading: 'Payments', body: 'Paid outside the app.'),
        LegalSection(heading: 'Cancellations', body: 'Ask staff.'),
      ]);

      final stored = (await db.doc('legal/terms').get()).data()!;
      expect(stored['updatedBy'], 'staff_919820000001');
      expect(stored['updatedAt'], isNotNull);
      expect(stored['sections'], hasLength(2));
      expect((await db.doc('legal/privacy').get()).exists, isFalse,
          reason: 'the other text is untouched');

      final back = (await repo.watchLegal(LegalKind.terms).first)!;
      expect(
          back.sections.map((s) => s.heading), ['Payments', 'Cancellations']);
      expect(back.sections.first.body, 'Paid outside the app.');
      expect(back.updatedAt, isNotNull);
    });

    test('a damaged section is skipped rather than crashing the page',
        () async {
      final db = FakeFirebaseFirestore();
      await db.doc('legal/privacy').set({
        'sections': [
          {'heading': 'Data we collect', 'body': 'Name and phone.'},
          'junk',
          {'heading': 5},
        ],
      });
      final doc = (await FirestoreContentRepository(db, () => null)
          .watchLegal(LegalKind.privacy)
          .first)!;
      expect(
          doc.sections.first,
          const LegalSection(
              heading: 'Data we collect', body: 'Name and phone.'));
      expect(doc.sections, hasLength(2));
    });
  });

  group('what customers see', () {
    testWidgets(
        'until staff write their own, the basic text is shown, with no made-up date',
        (tester) async {
      await pump(tester, const TermsPrivacyScreen(isTerms: true));
      expect(find.text('Holds and confirmation'), findsOneWidget);
      expect(find.textContaining('Last updated'), findsNothing);
    });

    testWidgets("it shows staff's sections and the date they were saved",
        (tester) async {
      final repo = MockContentRepository();
      await repo.saveLegal(LegalKind.privacy, const [
        LegalSection(
            heading: 'Data we collect', body: 'Your name and mobile number.')
      ]);
      await pump(tester, const TermsPrivacyScreen(isTerms: false),
          content: repo);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Data we collect'), findsOneWidget);
      expect(find.text('Your name and mobile number.'), findsOneWidget);
      expect(find.textContaining('Last updated 14 Sep 2026'), findsOneWidget);
    });

    testWidgets('terms and privacy are separate texts', (tester) async {
      final repo = MockContentRepository();
      await repo.saveLegal(LegalKind.terms, const [
        LegalSection(heading: 'Holds', body: 'A hold lasts 30 minutes.')
      ]);
      await pump(tester, const TermsPrivacyScreen(isTerms: false),
          content: repo);
      expect(find.text('Holds'), findsNothing);
      expect(find.text('What we collect'), findsOneWidget);
    });

    testWidgets('an edit made by staff appears without reopening the page',
        (tester) async {
      final repo = await pump(tester, const TermsPrivacyScreen(isTerms: true));
      await repo.saveLegal(LegalKind.terms,
          const [LegalSection(heading: 'New rule', body: 'Added just now.')]);
      await settle(tester);
      expect(find.text('New rule'), findsOneWidget);
    });
  });

  group('staff editor', () {
    testWidgets(
        'starts from the basic text, lets staff change it, and saves it for customers',
        (tester) async {
      final repo =
          await pump(tester, const LegalEditorScreen(kind: LegalKind.terms));
      expect(find.text('About the service'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'About the service'), '  Payments  ');
      await tester.enterText(
          find.widgetWithText(TextField, 'Text of this section').first,
          'Payments are made outside the app.');

      final position =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      // The list builds lazily, so its length is only known as it is scrolled.
      for (var i = 0; i < 6; i++) {
        position.jumpTo(position.maxScrollExtent);
        await settle(tester);
      }
      await settle(tester);
      await tester.tap(find.text('Save Terms & Conditions'));
      await settle(tester);

      final saved = (await repo.watchLegal(LegalKind.terms).first)!;
      expect(
          saved.sections.first,
          const LegalSection(
              heading: 'Payments', body: 'Payments are made outside the app.'));
      expect(saved.sections, hasLength(legalDefaults[LegalKind.terms]!.length));
      expect(find.textContaining('Customers see it now'), findsOneWidget);
    });

    testWidgets(
        'shows what is stored, lets a section be removed, and saves the rest',
        (tester) async {
      final repo = MockContentRepository();
      await repo.saveLegal(LegalKind.privacy, const [
        LegalSection(heading: 'One', body: 'First'),
        LegalSection(heading: 'Two', body: 'Second'),
      ]);
      await pump(tester, const LegalEditorScreen(kind: LegalKind.privacy),
          content: repo);
      expect(find.text('One'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove section').first);
      await settle(tester);
      expect(find.text('One'), findsNothing);

      await tester.ensureVisible(find.text('Save Privacy Policy'));
      await settle(tester);
      await tester.tap(find.text('Save Privacy Policy'));
      await settle(tester);
      expect(
          (await repo.watchLegal(LegalKind.privacy).first)!
              .sections
              .map((s) => s.heading),
          ['Two']);
    });
  });
}
