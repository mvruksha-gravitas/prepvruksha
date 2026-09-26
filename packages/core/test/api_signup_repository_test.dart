import 'dart:convert';

import 'package:core/core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _state = {
  'status': 'needs_parental',
  'is_minor': true,
  'terms_version': '2026-10-draft',
  'parental_version': '2026-10-draft',
  'pending_request': {
    'parent_name': 'Sunita',
    'parent_phone_last4': '0006',
    'expires_at': '2026-10-01T10:10:00+00:00',
    'attempts_left': 4,
    'resend_available_at': '2026-10-01T10:01:00+00:00',
  },
};

void main() {
  late List<http.Request> requests;

  ApiSignupRepository repo(
    http.Response Function(http.Request) respond, {
    String? token = 'tok',
  }) {
    requests = [];
    return ApiSignupRepository(
      baseUrl: 'http://api.test',
      accessToken: () async => token,
      client: MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
    );
  }

  http.Response ok(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );

  test('reads the signup state with the bearer token', () async {
    final state = await repo((_) => ok(_state)).fetchState();
    expect(requests.single.url.toString(), 'http://api.test/me/signup');
    expect(requests.single.headers['Authorization'], 'Bearer tok');
    expect(state.status, SignupStatus.needsParental);
    expect(state.isMinor, isTrue);
    expect(state.pendingRequest!.parentPhoneLast4, '0006');
    expect(state.pendingRequest!.attemptsLeft, 4);
  });

  test('sends the profile as JSON with a plain date', () async {
    await repo((_) => ok(_state)).completeProfile(
      ProfileInput(
        fullName: ' Asha ',
        dateOfBirth: DateTime(2010, 5, 7),
        targetExamYear: 2027,
        preferredLanguage: 'kn',
      ),
    );
    final request = requests.single;
    expect(request.method, 'PUT');
    expect(jsonDecode(request.body), {
      'full_name': 'Asha',
      'date_of_birth': '2010-05-07',
      'target_exam_year': 2027,
      'category': null,
      'preferred_language': 'kn',
    });
  });

  test('reads the code result', () async {
    final outcome = await repo(
      (_) => ok({'result': 'invalid', 'attempts_left': 3, 'state': _state}),
    ).verifyParentCode('000000');
    expect(outcome.result, ParentCodeResult.invalid);
    expect(outcome.attemptsLeft, 3);
    expect(jsonDecode(requests.single.body), {'code': '000000'});
  });

  test('withdraws by consent type', () async {
    await repo((_) => ok(_state)).withdrawConsent(ConsentType.parental);
    expect(requests.single.url.path, '/me/consents/parental/withdraw');
  });

  test('API errors carry their code', () async {
    final r = repo(
      (_) => http.Response(
        jsonEncode({
          'detail': {'code': 'age_out_of_range'},
        }),
        422,
      ),
    );
    expect(
      r.fetchState(),
      throwsA(
        isA<SignupFailure>().having((f) => f.code, 'code', 'age_out_of_range'),
      ),
    );
  });

  test('validation errors become invalid_input', () async {
    final r = repo(
      (_) => http.Response(
        jsonEncode({
          'detail': [<String, Object?>{}],
        }),
        422,
      ),
    );
    expect(
      r.fetchState(),
      throwsA(
        isA<SignupFailure>().having((f) => f.code, 'code', 'invalid_input'),
      ),
    );
  });

  test('connection problems are network failures', () async {
    final r = ApiSignupRepository(
      baseUrl: 'http://api.test',
      accessToken: () async => 'tok',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(
      r.fetchState(),
      throwsA(isA<SignupFailure>().having((f) => f.code, 'code', 'network')),
    );
  });

  test('no request is made when signed out', () async {
    final r = repo((_) => ok(_state), token: null);
    await expectLater(r.fetchState(), throwsA(isA<SignupFailure>()));
    expect(requests, isEmpty);
  });
}
