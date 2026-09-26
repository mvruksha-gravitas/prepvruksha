import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../auth/auth.dart';
import '../profile/profile.dart';
import '../shared/shared.dart';

final signupRepositoryProvider = Provider<SignupRepository>((ref) {
  final auth = Supabase.instance.client.auth;
  return ApiSignupRepository(
    baseUrl: ref.watch(appConfigProvider).apiUrl,
    // supabase_flutter refreshes the session before it expires.
    accessToken: () async => auth.currentSession?.accessToken,
  );
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
    final userId = ref.watch(userIdProvider);
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
