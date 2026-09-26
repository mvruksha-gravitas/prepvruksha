import 'dart:async';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepvruksha_console/src/app/app.dart';
import 'package:prepvruksha_console/src/auth/auth.dart';
import 'package:prepvruksha_console/src/content/content.dart';
import 'package:prepvruksha_console/src/staff/staff.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this._user});

  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  Future<void> sendOtp(PhoneNumber phone) async {}

  @override
  Future<void> verifyOtp(PhoneNumber phone, String code) async {
    if (code != '123456') {
      throw const AuthFailure(AuthFailureCode.invalidCode);
    }
    _set(AuthUser(id: 'u1', phone: phone.e164.substring(1)));
  }

  @override
  Future<void> signOut() async => _set(null);

  void _set(AuthUser? user) {
    _user = user;
    _changes.add(user);
  }
}

class FakeStaffRepository implements StaffRepository {
  FakeStaffRepository(this.roles);

  Set<StaffRole> roles;
  ApiFailure? nextFailure;

  @override
  Future<StaffMember> fetchMe() async {
    if (nextFailure case final failure?) {
      nextFailure = null;
      throw failure;
    }
    return StaffMember(userId: 'u1', roles: roles);
  }
}

SourceFile sourceFile({
  String id = 'f1',
  String name = 'Set A.pdf',
  RightsStatus rights = RightsStatus.ownedLicensed,
  SourceFileStatus status = SourceFileStatus.queued,
  String? pyqExamCode,
  int? pyqYear,
}) => SourceFile(
  id: id,
  originalName: name,
  fileType: SourceFileType.forFileName(name) ?? SourceFileType.pdf,
  sizeBytes: 2 * 1024 * 1024,
  sha256: 'ab',
  rightsStatus: rights,
  rightsNote: 'note',
  pyqExamCode: pyqExamCode,
  pyqYear: pyqYear,
  status: status,
  createdAt: DateTime.utc(2026, 9, 30, 10),
);

class FakeContentRepository implements ContentRepository {
  final files = <SourceFile>[];
  final created = <NewSourceFile>[];
  final uploads = <(String, int, SourceFileType)>[];
  final completed = <String>[];
  ApiFailure? createFailure;
  ApiFailure? uploadFailure;
  ({SourceFileStatus? status, RightsStatus? rights})? lastFilters;

  @override
  Future<List<SourceFile>> listFiles({
    SourceFileStatus? status,
    RightsStatus? rightsStatus,
  }) async {
    lastFilters = (status: status, rights: rightsStatus);
    return [
      for (final f in files)
        if ((status == null || f.status == status) &&
            (rightsStatus == null || f.rightsStatus == rightsStatus))
          f,
    ];
  }

  @override
  Future<CreatedSourceFile> createFile(NewSourceFile file) async {
    if (createFailure case final failure?) throw failure;
    created.add(file);
    return CreatedSourceFile(
      file: sourceFile(
        id: 'new',
        name: file.originalName,
        rights: file.rights.status,
        status: SourceFileStatus.awaitingUpload,
      ),
      uploadUrl: 'https://storage.test/sign',
    );
  }

  @override
  Future<void> upload(
    String uploadUrl,
    Uint8List bytes,
    SourceFileType fileType,
  ) async {
    if (uploadFailure case final failure?) throw failure;
    uploads.add((uploadUrl, bytes.length, fileType));
  }

  @override
  Future<SourceFile> completeUpload(String fileId) async {
    completed.add(fileId);
    final file = sourceFile(
      id: fileId,
      name: created.last.originalName,
      rights: created.last.rights.status,
    );
    files.insert(0, file);
    return file;
  }

  @override
  Future<SourceFile> changeRights(
    String fileId,
    RightsInput rights, {
    required String reason,
  }) async => throw UnimplementedError();
}

class FakePickedFile implements PickedFile {
  FakePickedFile(this.name, {int size = 1000, int? declaredSize})
    : _bytes = Uint8List(size),
      size = declaredSize ?? size;

  final Uint8List _bytes;

  @override
  final String name;

  @override
  final int? size;

  @override
  Future<Uint8List> readBytes() async => _bytes;
}

class FakeFilePicker implements FilePickerService {
  PickedFile? next;

  @override
  Future<PickedFile?> pickSourceFile() async => next;
}

/// The console with fakes; [user] is signed in when given.
Widget console({
  required FakeAuthRepository auth,
  FakeStaffRepository? staff,
  FakeContentRepository? content,
  FakeFilePicker? picker,
}) => ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(auth),
    staffRepositoryProvider.overrideWithValue(
      staff ?? FakeStaffRepository({StaffRole.contentAdmin}),
    ),
    contentRepositoryProvider.overrideWithValue(
      content ?? FakeContentRepository(),
    ),
    filePickerProvider.overrideWithValue(picker ?? FakeFilePicker()),
  ],
  child: const ConsoleApp(),
);
