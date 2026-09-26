enum AuthFailureCode { invalidCode, rateLimited, network, unknown }

/// An authentication error mapped to something the UI can explain.
class AuthFailure implements Exception {
  const AuthFailure(this.code, [this.message]);

  final AuthFailureCode code;

  /// Original error text, for logs only. Not shown to users.
  final String? message;

  @override
  String toString() =>
      'AuthFailure(${code.name}${message == null ? '' : ': $message'})';
}
