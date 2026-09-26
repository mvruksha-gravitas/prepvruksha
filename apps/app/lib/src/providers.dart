import 'dart:async';

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

final signupRepositoryProvider = Provider<SignupRepository>((ref) {
  final auth = Supabase.instance.client.auth;
  return ApiSignupRepository(
    baseUrl: ref.watch(appConfigProvider).apiUrl,
    // supabase_flutter refreshes the session before it expires.
    accessToken: () async => auth.currentSession?.accessToken,
  );
});

final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// The signed-in user's id; changes only on sign-in and sign-out (not on
/// token refreshes).
final _userIdProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider.select((user) => user.value?.id)),
);

/// The signed-in user's profile. Refetched when the user changes.
final ownProfileProvider = FutureProvider<Profile?>((ref) async {
  final userId = ref.watch(_userIdProvider);
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchOwn();
});

/// Where the signed-in user is in signup; null when signed out. The router
/// sends users to the matching step until the status is complete.
///
/// No automatic retry: the gate screen shows the error with a retry button.
final signupStateProvider =
    AsyncNotifierProvider<SignupController, SignupState?>(
      SignupController.new,
      retry: (retryCount, error) => null,
    );

class SignupController extends AsyncNotifier<SignupState?> {
  @override
  Future<SignupState?> build() async {
    final userId = ref.watch(_userIdProvider);
    if (userId == null) return null;
    return ref.watch(signupRepositoryProvider).fetchState();
  }

  SignupRepository get _repo => ref.read(signupRepositoryProvider);

  // Each action throws SignupFailure to the calling screen, which shows it.

  Future<void> completeProfile(ProfileInput input) async {
    _set(await _repo.completeProfile(input));
    ref.invalidate(ownProfileProvider);
  }

  Future<void> acceptTerms(String policyVersion) async =>
      _set(await _repo.acceptTerms(policyVersion));

  Future<void> startParentalConsent({
    required String parentName,
    required String parentPhone,
  }) async => _set(
    await _repo.startParentalConsent(
      parentName: parentName,
      parentPhone: parentPhone,
    ),
  );

  Future<ParentCodeOutcome> verifyParentCode(String code) async {
    final outcome = await _repo.verifyParentCode(code);
    _set(outcome.state);
    return outcome;
  }

  Future<void> withdrawConsent(ConsentType type) async =>
      _set(await _repo.withdrawConsent(type));

  /// Reloads after an error.
  void retry() => ref.invalidateSelf();

  void _set(SignupState value) => state = AsyncData(value);
}

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
