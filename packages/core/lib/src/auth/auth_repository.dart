import 'auth_user.dart';
import 'phone_number.dart';

/// Phone OTP authentication. Implementations throw `AuthFailure` on error.
abstract interface class AuthRepository {
  AuthUser? get currentUser;

  /// Emits the current user on every sign-in and sign-out.
  Stream<AuthUser?> authStateChanges();

  /// Sends a one-time code by SMS.
  Future<void> sendOtp(PhoneNumber phone);

  /// Verifies the code and signs the user in.
  Future<void> verifyOtp(PhoneNumber phone, String code);

  Future<void> signOut();
}
