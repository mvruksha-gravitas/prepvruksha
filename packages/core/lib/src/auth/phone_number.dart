import 'package:meta/meta.dart';

/// An Indian mobile number, stored as its 10 national digits.
@immutable
class PhoneNumber {
  const PhoneNumber._(this.nationalNumber);

  /// Parses user input such as `98765 43210`, `+91 98765-43210` or
  /// `098765 43210`. Returns null when the input is not a valid Indian
  /// mobile number (10 digits starting with 6–9).
  static PhoneNumber? tryParse(String input) {
    var digits = input.replaceAll(RegExp(r'[\s\-().]'), '');
    if (digits.startsWith('+91')) {
      digits = digits.substring(3);
    } else if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) return null;
    return PhoneNumber._(digits);
  }

  final String nationalNumber;

  /// E.164 format, as Supabase Auth expects: `+919876543210`.
  String get e164 => '+91$nationalNumber';

  /// For display: `+91 98765 43210`.
  String get display =>
      '+91 ${nationalNumber.substring(0, 5)} ${nationalNumber.substring(5)}';

  @override
  bool operator ==(Object other) =>
      other is PhoneNumber && other.nationalNumber == nationalNumber;

  @override
  int get hashCode => nationalNumber.hashCode;

  @override
  String toString() => e164;
}
