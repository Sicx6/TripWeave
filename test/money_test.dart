import 'package:flutter_test/flutter_test.dart';
import 'package:tripweave/core/utils/money.dart';

void main() {
  group('money parsing', () {
    test('converts ringgit and cents without floating-point arithmetic', () {
      expect(parseMoneyToCents('1250.90'), 125090);
      expect(parseMoneyToCents('10.1'), 1010);
      expect(parseMoneyToCents('25'), 2500);
    });

    test('rejects invalid monetary values', () {
      expect(parseMoneyToCents('-10'), isNull);
      expect(parseMoneyToCents('10.999'), isNull);
      expect(parseMoneyToCents('hello'), isNull);
    });
  });
}
