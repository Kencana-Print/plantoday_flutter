import 'package:flutter_test/flutter_test.dart';
import 'package:plantoday_flutter/core/utils/format_helper.dart';

void main() {
  group('FormatHelper.shortNum', () {
    test('formats small numbers without suffix', () {
      expect(FormatHelper.shortNum(0), '0');
      expect(FormatHelper.shortNum(450), '450');
      expect(FormatHelper.shortNum(999), '999');
    });

    test('formats thousands with rb', () {
      expect(FormatHelper.shortNum(1000), '1rb');
      expect(FormatHelper.shortNum(25000), '25rb');
      expect(FormatHelper.shortNum(999000), '999rb');
    });

    test('formats millions with jt', () {
      expect(FormatHelper.shortNum(1000000), '1.0jt');
      expect(FormatHelper.shortNum(1500000), '1.5jt');
      expect(FormatHelper.shortNum(250000000), '250.0jt');
    });

    test('formats billions with M', () {
      expect(FormatHelper.shortNum(1000000000), '1.0M');
      expect(FormatHelper.shortNum(2500000000), '2.5M');
    });

    test('formats trillions with T', () {
      expect(FormatHelper.shortNum(1000000000000), '1.0T');
      expect(FormatHelper.shortNum(3200000000000), '3.2T');
    });

    test('handles negative values correctly', () {
      expect(FormatHelper.shortNum(-500), '-500');
      expect(FormatHelper.shortNum(-1500000), '-1.5jt');
    });
  });
}
