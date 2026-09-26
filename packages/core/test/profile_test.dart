import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  test('Profile.fromJson reads a profiles row', () {
    final profile = Profile.fromJson({
      'id': 'u1',
      'full_name': 'Asha',
      'phone': '919999900001',
      'preferred_language': 'kn',
      'date_of_birth': '2009-06-01',
      'target_exam_year': 2027,
    });
    expect(profile.preferredLanguage, 'kn');
    expect(profile.dateOfBirth, DateTime(2009, 6, 1));
    expect(profile.isComplete, isTrue);
  });

  test('a new profile is incomplete', () {
    expect(Profile.fromJson({'id': 'u1'}).isComplete, isFalse);
  });
}
