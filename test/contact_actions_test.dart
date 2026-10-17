import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/core/utils/contact_launcher.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/features/customer/widgets/contact_help_footer.dart';
import 'package:charter_booking_ui/features/customer/widgets/driver_card.dart';

class FakeOpener implements UrlOpener {
  final List<Uri> opened = [];
  bool canOpen = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return canOpen;
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> pump(WidgetTester tester, Widget child, FakeOpener opener, {AppConfig? config}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final backend = MockBackend();
  if (config != null) backend.config.value = config;
  await tester.pumpWidget(ProviderScope(
    overrides: [mockBackendProvider.overrideWithValue(backend), urlOpenerProvider.overrideWithValue(opener)],
    child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child))),
  ));
  await settle(tester);
}

void main() {
  group('turning a number into something dialable', () {
    test('a plain ten-digit Indian number gets +91', () => expect(dialableNumber('98200 11223'), '919820011223'));
    test('already with country code, spaces and plus', () => expect(dialableNumber('+91 98200 11223'), '919820011223'));
    test('a leading zero is dropped', () => expect(dialableNumber('09820011223'), '919820011223'));
    test('dashes and brackets are ignored', () => expect(dialableNumber('(+91) 98200-11223'), '919820011223'));
    test('nothing, too short and too long are not numbers', () {
      expect(dialableNumber(''), isNull);
      expect(dialableNumber('12345'), isNull);
      expect(dialableNumber('1' * 20), isNull);
    });

    test('phone and WhatsApp links', () {
      expect(phoneUri('+91 98200 11223').toString(), 'tel:+919820011223');
      expect(whatsappUri('98200 11223').toString(), 'https://wa.me/919820011223');
      expect(whatsappUri('98200 11223', message: 'Hello & help').toString(), 'https://wa.me/919820011223?text=Hello+%26+help');
      expect(phoneUri('n/a'), isNull);
      expect(whatsappUri(''), isNull);
    });
  });

  group('the support buttons', () {
    const config = AppConfig(supportPhone: '+91 98200 11111', whatsappNumber: '+91 98200 22222');

    testWidgets('Call us dials the support number staff configured', (tester) async {
      final opener = FakeOpener();
      await pump(tester, const ContactActions(), opener, config: config);
      await tester.tap(find.text('Call us'));
      await settle(tester);
      expect(opener.opened.single.toString(), 'tel:+919820011111');
    });

    testWidgets('WhatsApp opens a chat with the WhatsApp number, which can differ from the phone number', (tester) async {
      final opener = FakeOpener();
      await pump(tester, const ContactActions(), opener, config: config);
      await tester.tap(find.text('WhatsApp'));
      await settle(tester);
      final uri = opener.opened.single;
      expect(uri.host, 'wa.me');
      expect(uri.path, '/919820022222');
      expect(uri.queryParameters['text'], isNotEmpty);
    });

    testWidgets('a phone that cannot make the call says so and shows the number', (tester) async {
      final opener = FakeOpener()..canOpen = false;
      await pump(tester, const ContactActions(), opener, config: config);
      await tester.tap(find.text('Call us'));
      await settle(tester);
      expect(find.textContaining('+91 98200 11111'), findsWidgets);
      expect(find.textContaining("Couldn't open the phone"), findsOneWidget);
    });

    testWidgets('a number that has not been set yet is explained and nothing is opened', (tester) async {
      final opener = FakeOpener();
      await pump(tester, const ContactActions(), opener, config: const AppConfig(supportPhone: '', whatsappNumber: ''));
      await tester.tap(find.text('WhatsApp'));
      await settle(tester);
      expect(opener.opened, isEmpty);
      expect(find.textContaining("isn't available yet"), findsOneWidget);
    });

    testWidgets('the help footer used on package screens works the same way', (tester) async {
      final opener = FakeOpener();
      await pump(tester, const ContactHelpFooter(message: 'Need help?'), opener, config: config);
      await tester.tap(find.text('Call us'));
      await settle(tester);
      expect(opener.opened.single.scheme, 'tel');
    });
  });

  group('the driver button', () {
    testWidgets("calls the driver's number", (tester) async {
      final opener = FakeOpener();
      await pump(tester, const DriverCard(driver: DriverInfo(name: 'Suresh Patil', phone: '+91 90000 11122', busNumber: 'MH-04-BT-7781')), opener);
      await tester.tap(find.byIcon(Icons.call_outlined));
      await settle(tester);
      expect(opener.opened.single.toString(), 'tel:+919000011122');
    });

    testWidgets('with no number to share there is no call button at all', (tester) async {
      await pump(tester, const DriverCard(driver: DriverInfo(name: 'Suresh Patil', busNumber: 'MH-04-BT-7781')), FakeOpener());
      expect(find.byIcon(Icons.call_outlined), findsNothing);
    });
  });
}
