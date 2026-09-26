import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'auth/supabase_auth_repository.dart';
import 'profile/supabase_profile_repository.dart';

/// Overridden in `main.dart` with the values from `--dart-define`.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(Supabase.instance.client.auth),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(Supabase.instance.client),
);

final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// The signed-in user's profile. Refetched when the user changes.
final ownProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.watch(profileRepositoryProvider).fetchOwn();
});

/// The language chosen in the app; null follows the device language.
/// Not persisted yet; it moves to `profiles.preferred_language` with signup.
final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  void toggle(Locale current) {
    state = Locale(current.languageCode == 'kn' ? 'en' : 'kn');
  }
}
