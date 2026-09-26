import 'dart:convert';

import 'package:http/http.dart' as http;

import 'signup_repository.dart';
import 'signup_state.dart';

/// Returns the signed-in user's current access token, or null.
typedef AccessTokenProvider = Future<String?> Function();

/// [SignupRepository] over the `services/api` `/me` endpoints.
class ApiSignupRepository implements SignupRepository {
  ApiSignupRepository({
    required this._baseUrl,
    required this._accessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String _baseUrl;
  final AccessTokenProvider _accessToken;
  final http.Client _client;

  static const _timeout = Duration(seconds: 20);

  @override
  Future<SignupState> fetchState() async =>
      SignupState.fromJson(await _send('GET', '/me/signup'));

  @override
  Future<SignupState> completeProfile(ProfileInput input) async =>
      SignupState.fromJson(await _send('PUT', '/me/profile', input.toJson()));

  @override
  Future<SignupState> acceptTerms(String policyVersion) async =>
      SignupState.fromJson(
        await _send('POST', '/me/consents/terms', {
          'policy_version': policyVersion,
        }),
      );

  @override
  Future<SignupState> startParentalConsent({
    required String parentName,
    required String parentPhone,
  }) async => SignupState.fromJson(
    await _send('POST', '/me/consents/parental', {
      'parent_name': parentName.trim(),
      'parent_phone': parentPhone,
    }),
  );

  @override
  Future<ParentCodeOutcome> verifyParentCode(String code) async {
    final json = await _send('POST', '/me/consents/parental/verify', {
      'code': code,
    });
    return ParentCodeOutcome(
      result: ParentCodeResult.fromWire(json['result']! as String),
      attemptsLeft: json['attempts_left'] as int?,
      state: SignupState.fromJson(json['state']! as Map<String, Object?>),
    );
  }

  @override
  Future<SignupState> withdrawConsent(ConsentType type) async =>
      SignupState.fromJson(
        await _send('POST', '/me/consents/${type.name}/withdraw'),
      );

  Future<Map<String, Object?>> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final token = await _accessToken();
    if (token == null) throw const SignupFailure('not_signed_in');

    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on Exception catch (e) {
      throw SignupFailure(SignupFailure.network, e.toString());
    }

    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw SignupFailure(SignupFailure.unknown, 'HTTP ${response.statusCode}');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json! as Map<String, Object?>;
    }
    throw SignupFailure(_errorCode(json), 'HTTP ${response.statusCode}');
  }

  /// Our errors are `{"detail": {"code": "..."}}`; validation errors from
  /// FastAPI are `{"detail": [...]}`.
  static String _errorCode(Object? json) {
    if (json case {'detail': {'code': final String code}}) return code;
    if (json case {'detail': List<Object?> _}) return 'invalid_input';
    return SignupFailure.unknown;
  }
}
