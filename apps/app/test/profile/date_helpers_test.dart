import 'package:flutter_test/flutter_test.dart';
import 'package:prepvruksha/src/profile/profile_screen.dart';

void main() {
  test('parseDate reads DD/MM/YYYY and rejects impossible dates', () {
    expect(parseDate('07/05/2010'), DateTime(2010, 5, 7));
    expect(parseDate('7/5/2010'), DateTime(2010, 5, 7));
    expect(parseDate('29/02/2011'), isNull);
    expect(parseDate('2010-05-07'), isNull);
  });

  test('ageOn counts whole years', () {
    final dob = DateTime(2008, 9, 27);
    expect(ageOn(dob, DateTime(2026, 9, 26)), 17);
    expect(ageOn(dob, DateTime(2026, 9, 27)), 18);
  });
}
