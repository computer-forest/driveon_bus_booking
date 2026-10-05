/// Hand-rolled rupee formatting, matching [AppDateFormat]'s approach in this
/// folder — no intl dependency for a UI-only prototype.
class AppMoneyFormat {
  AppMoneyFormat._();

  /// Indian digit grouping: the last three digits, then pairs.
  /// 10500 → ₹10,500 · 150000 → ₹1,50,000
  static String rupees(int amount) {
    final digits = amount.abs().toString();
    final String grouped;

    if (digits.length <= 3) {
      grouped = digits;
    } else {
      final lastThree = digits.substring(digits.length - 3);
      var rest = digits.substring(0, digits.length - 3);
      final parts = <String>[];
      while (rest.length > 2) {
        parts.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) parts.insert(0, rest);
      grouped = '${parts.join(',')},$lastThree';
    }

    return amount < 0 ? '-₹$grouped' : '₹$grouped';
  }
}
