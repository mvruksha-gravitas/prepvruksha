import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../api/api_failure.dart';
import 'source_file.dart';

/// Source files for the import pipeline, backed by `services/api`
/// `/content/files`. Implementations throw `ApiFailure` on error.
abstract interface class ContentRepository {
  Future<List<SourceFile>> listFiles({
    SourceFileStatus? status,
    RightsStatus? rightsStatus,
  });

  /// Records the file and returns a signed upload URL for its bytes.
  Future<CreatedSourceFile> createFile(NewSourceFile file);

  /// PUTs the bytes to the signed URL (straight to Storage, not the API).
  Future<void> upload(
    String uploadUrl,
    Uint8List bytes,
    SourceFileType fileType,
  );

  /// Confirms the upload; the file becomes `queued` with an import job.
  Future<SourceFile> completeUpload(String fileId);

  Future<SourceFile> changeRights(
    String fileId,
    RightsInput rights, {
    required String reason,
  });
}

class ApiContentRepository implements ContentRepository {
  ApiContentRepository(this._api, {http.Client? uploadClient})
    : _uploadClient = uploadClient ?? http.Client();

  final ApiClient _api;
  final http.Client _uploadClient;

  static const _uploadTimeout = Duration(minutes: 15);

  @override
  Future<List<SourceFile>> listFiles({
    SourceFileStatus? status,
    RightsStatus? rightsStatus,
  }) async {
    final json = await _api.send(
      'GET',
      '/content/files',
      query: {'status': ?status?.wire, 'rights_status': ?rightsStatus?.wire},
    );
    return [
      for (final item in json! as List<Object?>)
        SourceFile.fromJson(item! as Map<String, Object?>),
    ];
  }

  @override
  Future<CreatedSourceFile> createFile(NewSourceFile file) async {
    final json =
        (await _api.send('POST', '/content/files', body: file.toJson()))!
            as Map<String, Object?>;
    return CreatedSourceFile(
      file: SourceFile.fromJson(json['file']! as Map<String, Object?>),
      uploadUrl: json['upload_url']! as String,
    );
  }

  @override
  Future<void> upload(
    String uploadUrl,
    Uint8List bytes,
    SourceFileType fileType,
  ) async {
    final http.Response response;
    try {
      response = await _uploadClient
          .put(
            Uri.parse(uploadUrl),
            headers: {'Content-Type': fileType.mimeType, 'x-upsert': 'true'},
            body: bytes,
          )
          .timeout(_uploadTimeout);
    } on Exception catch (e) {
      throw ApiFailure(ApiFailure.network, e.toString());
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFailure('upload_failed', 'HTTP ${response.statusCode}');
    }
  }

  @override
  Future<SourceFile> completeUpload(String fileId) async => SourceFile.fromJson(
    (await _api.send('POST', '/content/files/$fileId/complete'))!
        as Map<String, Object?>,
  );

  @override
  Future<SourceFile> changeRights(
    String fileId,
    RightsInput rights, {
    required String reason,
  }) async => SourceFile.fromJson(
    (await _api.send(
          'PATCH',
          '/content/files/$fileId/rights',
          body: {...rights.toJson(), 'reason': reason.trim()},
        ))!
        as Map<String, Object?>,
  );
}
