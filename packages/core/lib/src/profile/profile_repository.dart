import 'profile.dart';

abstract interface class ProfileRepository {
  /// The signed-in user's profile, or null if it doesn't exist yet.
  Future<Profile?> fetchOwn();
}
