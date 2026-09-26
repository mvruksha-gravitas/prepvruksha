import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('PhoneNumber.tryParse', () {
    for (final input in [
      '9876543210',
      '98765 43210',
      '+91 98765-43210',
      '+919876543210',
      '919876543210',
      '09876543210',
    ]) {
      test('accepts "$input"', () {
        expect(PhoneNumber.tryParse(input)?.e164, '+919876543210');
      });
    }

    for (final input in [
      '',
      '12345',
      '5876543210', // must start with 6-9
      '98765432101', // 11 digits
      '+1 9876543210',
      '98765abcde',
    ]) {
      test('rejects "$input"', () {
        expect(PhoneNumber.tryParse(input), isNull);
      });
    }

    test('formats for display', () {
      expect(PhoneNumber.tryParse('9876543210')!.display, '+91 98765 43210');
    });
  });
}
