import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../auth/auth.dart';
import 'supabase_profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(Supabase.instance.client),
);

/// The signed-in user's profile. Refetched when the user changes.
final ownProfileProvider = FutureProvider<Profile?>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchOwn();
});

/// NEET target exam years the profile step offers, from the exam dates on
/// record. The database applies the same rule when the profile is saved.
///
/// No automatic retry: the profile screen shows the error with a retry button.
final targetExamYearsProvider = FutureProvider<List<int>>(
  (ref) => ref.watch(profileRepositoryProvider).fetchTargetExamYears(),
  retry: (retryCount, error) => null,
);

/// The language chosen in the app; null follows the device language.
/// Saved to `profiles.preferred_language` when signed in, and restored from
/// it once the profile is complete (a new profile's default is not a choice).
final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    ref.listen(ownProfileProvider, (_, next) {
      final profile = next.value;
      if (profile != null && profile.isComplete) {
        state = Locale(profile.preferredLanguage);
      }
    }, fireImmediately: true);
    return null;
  }

  void toggle(Locale current) {
    final next = current.languageCode == 'kn' ? 'en' : 'kn';
    state = Locale(next);
    if (ref.read(authRepositoryProvider).currentUser != null) {
      // Best effort: the choice still applies for this session if saving fails.
      unawaited(
        ref
            .read(profileRepositoryProvider)
            .updatePreferredLanguage(next)
            .catchError((Object _) {}),
      );
    }
  }

  /// Applies a language without saving it (the profile form saves it).
  void preview(String languageCode) => state = Locale(languageCode);
}
