import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

const _staffUser = AuthUser(id: 'u1', phone: '919999900002');

void main() {
  testWidgets('signed out: phone sign-in, then the file list', (tester) async {
    final auth = FakeAuthRepository();
    await tester.pumpWidget(console(auth: auth));
    await tester.pumpAndSettle();

    expect(find.text('Staff sign-in'), findsOneWidget);
    expect(find.text('Phone (one-time code)'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('phone-field')), '9999900002');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('otp-field')), '123456');
    await tester.pumpAndSettle();

    expect(find.text('Source files'), findsOneWidget);
    expect(find.text('Roles: Content admin'), findsOneWidget);
  });

  testWidgets('non-staff see "No access" and can sign out', (tester) async {
    final auth = FakeAuthRepository(user: _staffUser);
    await tester.pumpWidget(
      console(auth: auth, staff: FakeStaffRepository({})),
    );
    await tester.pumpAndSettle();

    expect(find.text('No access'), findsOneWidget);
    expect(find.textContaining('919999900002'), findsOneWidget);
    expect(find.text('Source files'), findsNothing);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Staff sign-in'), findsOneWidget);
  });

  testWidgets('a failed access check offers retry', (tester) async {
    final staff = FakeStaffRepository({StaffRole.reviewer})
      ..nextFailure = const ApiFailure(ApiFailure.network);
    await tester.pumpWidget(
      console(
        auth: FakeAuthRepository(user: _staffUser),
        staff: staff,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("We couldn't check your access."), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Source files'), findsOneWidget);
  });

  testWidgets('reviewers see the list but no upload button', (tester) async {
    final content = FakeContentRepository()
      ..files.add(
        sourceFile(
          name: 'NEET 2023.pdf',
          rights: RightsStatus.officialPyq,
          pyqExamCode: 'NEET_UG',
          pyqYear: 2023,
        ),
      );
    await tester.pumpWidget(
      console(
        auth: FakeAuthRepository(user: _staffUser),
        staff: FakeStaffRepository({StaffRole.reviewer}),
        content: content,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('NEET 2023.pdf'), findsOneWidget);
    expect(
      find.text('Official previous-year paper · NEET-UG 2023'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('upload-button')), findsNothing);
  });

  testWidgets('an empty filtered list says nothing matches', (tester) async {
    final content = FakeContentRepository()..files.add(sourceFile());
    await tester.pumpWidget(
      console(
        auth: FakeAuthRepository(user: _staffUser),
        content: content,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('All rights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reference only').last);
    await tester.pumpAndSettle();

    expect(content.lastFilters?.rights, RightsStatus.referenceOnly);
    expect(find.text('No files match these filters.'), findsOneWidget);
  });
}
