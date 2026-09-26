abstract final class Routes {
  static const home = '/';
  static const login = '/login';
  static const otp = '/login/otp';

  /// Loading the signup state, or an error with retry.
  static const gate = '/start';
  static const profile = '/signup/profile';
  static const terms = '/signup/terms';
  static const parent = '/signup/parent';

  /// Placeholder terms and privacy text; open at any stage.
  static const policy = '/policy';
}
