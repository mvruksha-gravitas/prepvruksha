import 'profile.dart';

abstract interface class ProfileRepository {
  /// The signed-in user's profile, or null if it doesn't exist yet.
  Future<Profile?> fetchOwn();

  /// Saves the app language (`en` or `kn`) to the signed-in user's profile.
  Future<void> updatePreferredLanguage(String languageCode);

  /// Target exam years a student may choose for [examCode], from the exam
  /// dates on record (the database's `target_exam_years` rule). Empty when no
  /// upcoming exam date is recorded.
  Future<List<int>> fetchTargetExamYears({String examCode = 'NEET_UG'});
}
