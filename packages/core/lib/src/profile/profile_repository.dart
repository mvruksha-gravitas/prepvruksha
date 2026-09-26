import 'profile.dart';

abstract interface class ProfileRepository {
  /// The signed-in user's profile, or null if it doesn't exist yet.
  Future<Profile?> fetchOwn();

  /// Saves the app language (`en` or `kn`) to the signed-in user's profile.
  Future<void> updatePreferredLanguage(String languageCode);
}
