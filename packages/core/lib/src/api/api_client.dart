import 'dart:convert';

import 'package:http/http.dart' as http;

import '../signup/api_signup_repository.dart' show AccessTokenProvider;
import 'api_failure.dart';

/// JSON calls to `services/api` with the signed-in user's token.
/// Throws [ApiFailure] on any error.
class ApiClient {
  ApiClient({
    required this._baseUrl,
    required this._accessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String _baseUrl;
  final AccessTokenProvider _accessToken;
  final http.Client _client;

  static const _timeout = Duration(seconds: 20);

  Future<Object?> send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
  }) async {
    final token = await _accessToken();
    if (token == null) throw const ApiFailure(ApiFailure.notSignedIn);

    var uri = Uri.parse('$_baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final request = http.Request(method, uri)
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
      throw ApiFailure(ApiFailure.network, e.toString());
    }

    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiFailure(ApiFailure.unknown, 'HTTP ${response.statusCode}');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    throw ApiFailure(errorCode(json), 'HTTP ${response.statusCode}');
  }

  /// Our errors are `{"detail": {"code": "..."}}`; validation errors from
  /// FastAPI are `{"detail": [...]}`.
  static String errorCode(Object? json) {
    if (json case {'detail': {'code': final String code}}) return code;
    if (json case {'detail': List<Object?> _}) return ApiFailure.invalidInput;
    return ApiFailure.unknown;
  }
}
