import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepvruksha_console/src/content/content.dart';

import '../fakes.dart';

const _admin = AuthUser(id: 'u1', phone: '919999900002');

void main() {
  late FakeContentRepository content;
  late FakeFilePicker picker;

  Future<void> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      console(
        auth: FakeAuthRepository(user: _admin),
        content: content,
        picker: picker,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('upload-button')));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, PickedFile file) async {
    picker.next = file;
    await tester.tap(find.byKey(const Key('choose-file')));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('upload-submit')));
    await tester.pumpAndSettle();
  }

  setUp(() {
    content = FakeContentRepository();
    picker = FakeFilePicker();
  });

  testWidgets('rights status has no default and a note is required', (
    tester,
  ) async {
    await openDialog(tester);
    await choose(tester, FakePickedFile('Set A.pdf'));
    await submit(tester);

    expect(find.text('Choose the rights status.'), findsOneWidget);
    expect(find.text('Write a rights note.'), findsOneWidget);
    expect(content.created, isEmpty);
  });

  testWidgets('owned file: hash, record, upload, confirm; listed as queued', (
    tester,
  ) async {
    await openDialog(tester);
    await choose(tester, FakePickedFile('Set A.pdf', size: 1234));
    await tester.tap(find.byKey(const Key('rights-owned_licensed')));
    await tester.enterText(
      find.byKey(const Key('rights-note')),
      'Written by our teachers',
    );
    await submit(tester);

    final created = content.created.single;
    expect(created.originalName, 'Set A.pdf');
    expect(created.sizeBytes, 1234);
    expect(created.sha256, hasLength(64));
    expect(created.rights.status, RightsStatus.ownedLicensed);
    expect(content.uploads.single, (
      'https://storage.test/sign',
      1234,
      SourceFileType.pdf,
    ));
    expect(content.completed, ['new']);

    expect(find.text('Upload a source file'), findsNothing);
    expect(find.text('Set A.pdf uploaded and queued for import.'), findsOne);
    expect(find.text('Queued'), findsOneWidget);
  });

  testWidgets('official PYQ needs a valid year; exam and year are sent', (
    tester,
  ) async {
    await openDialog(tester);
    await choose(tester, FakePickedFile('NEET 2023.docx'));
    await tester.tap(find.byKey(const Key('rights-official_pyq')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rights-note')), 'NTA paper');
    await tester.enterText(find.byKey(const Key('pyq-year')), '2999');
    await submit(tester);

    expect(find.textContaining('Enter a year between 1980'), findsOneWidget);
    expect(content.created, isEmpty);

    await tester.enterText(find.byKey(const Key('pyq-year')), '2023');
    await submit(tester);

    final rights = content.created.single.rights;
    expect(rights.status, RightsStatus.officialPyq);
    expect(rights.pyqExamCode, 'NEET_UG');
    expect(rights.pyqYear, 2023);
    expect(content.uploads.single.$3, SourceFileType.docx);
  });

  testWidgets('files that are too large or of the wrong type are refused', (
    tester,
  ) async {
    await openDialog(tester);
    await choose(
      tester,
      FakePickedFile('big.pdf', size: 1, declaredSize: maxSourceFileBytes + 1),
    );
    expect(find.text('The file is larger than 100 MB.'), findsOneWidget);

    await choose(tester, FakePickedFile('notes.doc'));
    expect(
      find.text('Only PDF (.pdf) and Word (.docx) files are accepted.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('rights-reference_only')));
    await tester.enterText(find.byKey(const Key('rights-note')), 'x');
    await submit(tester);
    expect(content.created, isEmpty);
  });

  testWidgets('a duplicate file shows a clear message and keeps the form', (
    tester,
  ) async {
    content.createFailure = const ApiFailure('duplicate_file');
    await openDialog(tester);
    await choose(tester, FakePickedFile('Set A.pdf'));
    await tester.tap(find.byKey(const Key('rights-reference_only')));
    await tester.enterText(find.byKey(const Key('rights-note')), 'Guide');
    await submit(tester);

    expect(find.text('This exact file was already uploaded.'), findsOneWidget);
    expect(find.text('Upload a source file'), findsOneWidget);
    expect(content.uploads, isEmpty);
  });

  testWidgets('a failed upload is reported and not confirmed', (tester) async {
    content.uploadFailure = const ApiFailure('upload_failed');
    await openDialog(tester);
    await choose(tester, FakePickedFile('Set A.pdf'));
    await tester.tap(find.byKey(const Key('rights-owned_licensed')));
    await tester.enterText(find.byKey(const Key('rights-note')), 'Ours');
    await submit(tester);

    expect(find.text('The upload failed. Try again.'), findsOneWidget);
    expect(content.completed, isEmpty);
  });
}
