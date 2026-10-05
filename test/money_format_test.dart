import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/utils/money_format.dart';

void main() {
  test('groups thousands the Indian way', () {
    expect(AppMoneyFormat.rupees(10500), '₹10,500');
    expect(AppMoneyFormat.rupees(16000), '₹16,000');
    expect(AppMoneyFormat.rupees(999), '₹999');
    expect(AppMoneyFormat.rupees(1000), '₹1,000');
  });

  test('groups lakhs and crores in pairs after the first three digits', () {
    expect(AppMoneyFormat.rupees(150000), '₹1,50,000');
    expect(AppMoneyFormat.rupees(1250000), '₹12,50,000');
    expect(AppMoneyFormat.rupees(10000000), '₹1,00,00,000');
  });

  test('handles zero and negatives', () {
    expect(AppMoneyFormat.rupees(0), '₹0');
    expect(AppMoneyFormat.rupees(-13500), '-₹13,500');
  });
}
