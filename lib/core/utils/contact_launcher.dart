import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a phone call or a chat. Behind an interface so screens can be tested
/// without a phone.
abstract class UrlOpener {
  /// True if the phone handed it to an app; false if nothing could open it.
  Future<bool> open(Uri uri);
}

class SystemUrlOpener implements UrlOpener {
  const SystemUrlOpener();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

/// Digits only, with India's country code added to a plain 10-digit number
/// (and a leading 0 dropped). Null when there is nothing usable to dial.
String? dialableNumber(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (digits.length == 10) digits = '91$digits';
  return digits.length >= 11 && digits.length <= 15 ? digits : null;
}

Uri? phoneUri(String raw) {
  final n = dialableNumber(raw);
  return n == null ? null : Uri(scheme: 'tel', path: '+$n');
}

Uri? whatsappUri(String raw, {String? message}) {
  final n = dialableNumber(raw);
  if (n == null) return null;
  return Uri.https('wa.me', '/$n', message == null ? null : {'text': message});
}

/// Opens [uri] and, if the phone cannot, tells the person and shows the
/// number so they can still use it by hand.
Future<void> openOrExplain(
  BuildContext context,
  UrlOpener opener,
  Uri? uri, {
  required String what,
  required String number,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (uri == null) {
    messenger.showSnackBar(SnackBar(content: Text("That $what number isn't available yet.")));
    return;
  }
  if (await opener.open(uri)) return;
  messenger.showSnackBar(SnackBar(
    content: Text("Couldn't open $what on this phone.${number.isEmpty ? '' : ' The number is $number.'}"),
  ));
}
