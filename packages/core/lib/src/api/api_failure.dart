/// An error from `services/api` (other than signup, which has
/// `SignupFailure`). [code] is the machine-readable code from the API
/// (for example `duplicate_file`), or one of the constants below.
class ApiFailure implements Exception {
  const ApiFailure(this.code, [this.message]);

  static const network = 'network';
  static const unknown = 'unknown';
  static const notSignedIn = 'not_signed_in';

  /// FastAPI rejected the request shape (HTTP 422 with a list of problems).
  static const invalidInput = 'invalid_input';

  final String code;

  /// Original error text, for logs only.
  final String? message;

  @override
  String toString() =>
      'ApiFailure($code${message == null ? '' : ': $message'})';
}
