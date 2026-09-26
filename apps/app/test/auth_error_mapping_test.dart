import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepvruksha/src/auth/supabase_auth_repository.dart';

void main() {
  test('maps Supabase Auth error codes', () {
    expect(mapAuthErrorCode('otp_expired', '403'), AuthFailureCode.invalidCode);
    expect(
      mapAuthErrorCode('over_sms_send_rate_limit', '429'),
      AuthFailureCode.rateLimited,
    );
    expect(mapAuthErrorCode(null, '429'), AuthFailureCode.rateLimited);
    expect(
      mapAuthErrorCode('unexpected_failure', '500'),
      AuthFailureCode.unknown,
    );
  });
}
