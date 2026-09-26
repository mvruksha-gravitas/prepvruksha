import 'dart:async';

import 'package:core/core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// [AuthRepository] backed by Supabase Auth phone OTP.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final sb.GoTrueClient _auth;

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() =>
      _auth.onAuthStateChange.map((state) => _toAuthUser(state.session?.user));

  @override
  Future<void> sendOtp(PhoneNumber phone) =>
      _guard(() => _auth.signInWithOtp(phone: phone.e164));

  @override
  Future<void> verifyOtp(PhoneNumber phone, String code) => _guard(
    () => _auth.verifyOTP(type: sb.OtpType.sms, phone: phone.e164, token: code),
  );

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  static AuthUser? _toAuthUser(sb.User? user) =>
      user == null ? null : AuthUser(id: user.id, phone: user.phone);

  static Future<void> _guard(Future<Object?> Function() call) async {
    try {
      await call();
    } on sb.AuthRetryableFetchException catch (e) {
      throw AuthFailure(AuthFailureCode.network, e.message);
    } on sb.AuthException catch (e) {
      throw AuthFailure(mapAuthErrorCode(e.code, e.statusCode), e.message);
    } on TimeoutException catch (e) {
      throw AuthFailure(AuthFailureCode.network, e.message);
    }
  }
}

/// Maps Supabase Auth error codes to [AuthFailureCode].
/// Supabase returns `otp_expired` for both wrong and expired codes.
AuthFailureCode mapAuthErrorCode(String? code, String? statusCode) {
  switch (code) {
    case 'otp_expired':
    case 'invalid_credentials':
      return AuthFailureCode.invalidCode;
    case 'over_request_rate_limit':
    case 'over_sms_send_rate_limit':
      return AuthFailureCode.rateLimited;
  }
  if (statusCode == '429') return AuthFailureCode.rateLimited;
  return AuthFailureCode.unknown;
}
