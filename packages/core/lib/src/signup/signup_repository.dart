import 'signup_state.dart';

/// Signup and consent, backed by `services/api`. Every call returns the fresh
/// state. Implementations throw [SignupFailure] on error.
abstract interface class SignupRepository {
  Future<SignupState> fetchState();

  Future<SignupState> completeProfile(ProfileInput input);

  Future<SignupState> acceptTerms(String policyVersion);

  /// Sends a code to the parent's phone. Also used to resend or change the number.
  Future<SignupState> startParentalConsent({
    required String parentName,
    required String parentPhone,
  });

  Future<ParentCodeOutcome> verifyParentCode(String code);

  Future<SignupState> withdrawConsent(ConsentType type);
}

/// An API error. [code] is the machine-readable code from the API
/// (for example `age_out_of_range`), or `network` / `unknown`.
class SignupFailure implements Exception {
  const SignupFailure(this.code, [this.message]);

  static const network = 'network';
  static const unknown = 'unknown';

  final String code;

  /// Original error text, for logs only.
  final String? message;

  @override
  String toString() =>
      'SignupFailure($code${message == null ? '' : ': $message'})';
}
