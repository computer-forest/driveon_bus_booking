/// Indian mobile numbers: the user types ten digits, the country code is
/// added in code.
class Phone {
  Phone._();

  static final _valid = RegExp(r'^[6-9]\d{9}$');

  static String digits(String input) => input.replaceAll(RegExp(r'\D'), '');

  static bool isValid(String input) => _valid.hasMatch(digits(input));

  /// Error text for the field, or null when the number is fine.
  static String? validate(String input) {
    final d = digits(input);
    if (d.isEmpty) return 'Enter your 10-digit mobile number.';
    if (d.length != 10) return 'Mobile number must be exactly 10 digits.';
    if (!_valid.hasMatch(d)) return 'Mobile number must start with 6, 7, 8 or 9.';
    return null;
  }

  /// MSG91 identifier: country code + number, digits only, no '+'.
  static String identifier(String input, {String countryCode = '91'}) => '$countryCode${digits(input)}';

  /// `9820011223` → `98200 11223`.
  static String pretty(String input) {
    final d = digits(input);
    return d.length == 10 ? '${d.substring(0, 5)} ${d.substring(5)}' : input;
  }

  /// `98200 XXXXX` — enough to recognise the number without exposing it.
  static String masked(String input) {
    final d = digits(input);
    return d.length == 10 ? '${d.substring(0, 5)} XXXXX' : input;
  }
}
