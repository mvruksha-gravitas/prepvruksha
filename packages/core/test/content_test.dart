import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _fileJson = {
  'id': 'f1',
  'original_name': 'NEET 2023.pdf',
  'file_type': 'pdf',
  'size_bytes': 2000,
  'sha256': 'ab',
  'storage_path': 'uploads/f1.pdf',
  'rights_status': 'official_pyq',
  'rights_note': 'NTA paper',
  'pyq_exam_code': 'NEET_UG',
  'pyq_year': 2023,
  'status': 'queued',
  'error': null,
  'uploaded_by': 'u1',
  'created_at': '2026-09-30T10:00:00+00:00',
  'queued_at': '2026-09-30T10:01:00+00:00',
};

http.Response _json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  late List<http.Request> requests;

  ApiClient client(http.Response Function(http.Request) handler) {
    requests = [];
    return ApiClient(
      baseUrl: 'https://api.test',
      accessToken: () async => 'token',
      client: MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  group('ApiContentRepository', () {
    test('lists files with filters and the bearer token', () async {
      final repo = ApiContentRepository(client((_) => _json([_fileJson])));
      final files = await repo.listFiles(
        rightsStatus: RightsStatus.officialPyq,
      );
      expect(files.single.pyqYear, 2023);
      expect(files.single.status, SourceFileStatus.queued);
      expect(files.single.queuedAt, isNotNull);
      expect(requests.single.url.queryParameters, {
        'rights_status': 'official_pyq',
      });
      expect(requests.single.headers['Authorization'], 'Bearer token');
    });

    test('create sends the rights and returns the upload url', () async {
      final repo = ApiContentRepository(
        client(
          (_) => _json({'file': _fileJson, 'upload_url': 'https://u'}, 201),
        ),
      );
      final created = await repo.createFile(
        const NewSourceFile(
          originalName: 'Guide.pdf',
          fileType: SourceFileType.pdf,
          sizeBytes: 10,
          sha256: 'cd',
          rights: RightsInput(
            status: RightsStatus.referenceOnly,
            note: '  Commercial guide  ',
            // Dropped: exam and year are only sent for official PYQs.
            pyqExamCode: 'NEET_UG',
            pyqYear: 2023,
          ),
        ),
      );
      expect(created.uploadUrl, 'https://u');
      expect(jsonDecode(requests.single.body), {
        'original_name': 'Guide.pdf',
        'file_type': 'pdf',
        'size_bytes': 10,
        'sha256': 'cd',
        'rights_status': 'reference_only',
        'rights_note': 'Commercial guide',
        'pyq_exam_code': null,
        'pyq_year': null,
      });
    });

    test('API error codes become ApiFailure codes', () async {
      final repo = ApiContentRepository(
        client(
          (_) => _json({
            'detail': {'code': 'duplicate_file'},
          }, 409),
        ),
      );
      await expectLater(
        repo.createFile(
          const NewSourceFile(
            originalName: 'a.pdf',
            fileType: SourceFileType.pdf,
            sizeBytes: 1,
            sha256: 'x',
            rights: RightsInput(status: RightsStatus.ownedLicensed, note: 'n'),
          ),
        ),
        throwsA(
          isA<ApiFailure>().having((f) => f.code, 'code', 'duplicate_file'),
        ),
      );
    });

    test('upload PUTs the bytes with the file type', () async {
      final uploads = <http.Request>[];
      final repo = ApiContentRepository(
        client((_) => _json({})),
        uploadClient: MockClient((request) async {
          uploads.add(request);
          return http.Response('{}', 200);
        }),
      );
      await repo.upload(
        'https://storage.test/sign?token=t',
        Uint8List.fromList([1, 2, 3]),
        SourceFileType.docx,
      );
      expect(uploads.single.method, 'PUT');
      expect(uploads.single.bodyBytes, [1, 2, 3]);
      expect(
        uploads.single.headers['Content-Type'],
        startsWith(SourceFileType.docx.mimeType),
      );
    });

    test('a failed upload is reported', () async {
      final repo = ApiContentRepository(
        client((_) => _json({})),
        uploadClient: MockClient((_) async => http.Response('no', 400)),
      );
      await expectLater(
        repo.upload('https://u', Uint8List(1), SourceFileType.pdf),
        throwsA(
          isA<ApiFailure>().having((f) => f.code, 'code', 'upload_failed'),
        ),
      );
    });

    test('change rights sends the reason', () async {
      final repo = ApiContentRepository(client((_) => _json(_fileJson)));
      await repo.changeRights(
        'f1',
        const RightsInput(status: RightsStatus.referenceOnly, note: 'Owner'),
        reason: ' Takedown ',
      );
      expect(requests.single.method, 'PATCH');
      expect(requests.single.url.path, '/content/files/f1/rights');
      expect(jsonDecode(requests.single.body)['reason'], 'Takedown');
    });
  });

  group('staff', () {
    test('roles are parsed; unknown roles are ignored', () async {
      final repo = ApiStaffRepository(
        client(
          (_) => _json({
            'user_id': 'u1',
            'roles': ['reviewer', 'something_new'],
          }),
        ),
      );
      final me = await repo.fetchMe();
      expect(me.roles, {StaffRole.reviewer});
      expect(me.isStaff, isTrue);
      expect(me.canUpload, isFalse);
    });

    test('super admins can upload', () {
      const me = StaffMember(userId: 'u', roles: {StaffRole.superAdmin});
      expect(me.canUpload, isTrue);
      expect(me.has(StaffRole.reviewer), isTrue);
    });
  });

  test('file types come from the extension', () {
    expect(SourceFileType.forFileName('Paper.PDF'), SourceFileType.pdf);
    expect(SourceFileType.forFileName('notes.docx'), SourceFileType.docx);
    expect(SourceFileType.forFileName('notes.doc'), isNull);
  });

  test('sha256Hex matches a known value and reports progress', () async {
    final progress = <double>[];
    final hash = await sha256Hex(
      Uint8List.fromList(utf8.encode('abc')),
      onProgress: progress.add,
      chunkSize: 2,
    );
    expect(
      hash,
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(progress.last, 1.0);
    expect(progress, hasLength(2));
  });
}
