import 'package:flutter_test/flutter_test.dart';
import 'package:tripweave/features/auth/presentation/screens/login_screen.dart';

void main() {
  group('email validation', () {
    test('accepts a normal email address', () {
      expect(validateEmail('traveller@example.com'), isNull);
    });

    test('rejects an incomplete email address', () {
      expect(validateEmail('traveller@'), isNotNull);
    });
  });
}
