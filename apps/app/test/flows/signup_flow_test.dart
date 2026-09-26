import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepvruksha/src/app.dart';
import 'package:prepvruksha/src/auth/phone_screen.dart';
import 'package:prepvruksha/src/home/home_screen.dart';
import 'package:prepvruksha/src/providers.dart';
import 'package:prepvruksha/src/router.dart';
import 'package:prepvruksha/src/signup/parent_consent_screen.dart';
import 'package:prepvruksha/src/signup/profile_screen.dart';
import 'package:prepvruksha/src/signup/terms_screen.dart';

import 'fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;
  late FakeSignupRepository signup;

  setUp(() async {
    auth = FakeAuthRepository();
    profiles = FakeProfileRepository();
    signup = FakeSignupRepository(status: SignupStatus.needsProfile);
    await auth.verifyOtp(PhoneNumber.tryParse('9999900001')!, '123456');
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(profiles),
          signupRepositoryProvider.overrideWithValue(signup),
        ],
        child: const PrepVrukshaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Removes the app so screen timers are cancelled before the test ends.
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  String yearsAgo(int years) {
    final now = DateTime.now();
    final d = DateTime(now.year - years, now.month, now.day);
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> fillProfile(WidgetTester tester, {required String dob}) async {
    await tester.enterText(find.byKey(const Key('name-field')), 'Asha');
    await tester.enterText(find.byKey(const Key('dob-field')), dob);
    await tester.tap(find.byKey(const Key('exam-year-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${DateTime.now().year + 1}').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> acceptTerms(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('terms-checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept and continue'));
    await tester.pumpAndSettle();
  }

  Future<void> sendToParent(WidgetTester tester, String phone) async {
    await tester.enterText(
      find.byKey(const Key('parent-name-field')),
      'Sunita',
    );
    await tester.enterText(find.byKey(const Key('parent-phone-field')), phone);
    await tester.tap(find.text('Send code to parent'));
    await tester.pumpAndSettle();
  }

  group('profile', () {
    testWidgets('a new user must complete their profile first', (tester) async {
      await pumpApp(tester);
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('a complete profile moves on to the terms', (tester) async {
      await pumpApp(tester);
      await fillProfile(tester, dob: yearsAgo(16));

      expect(find.byType(TermsScreen), findsOneWidget);
      final saved = signup.savedProfile!;
      expect(saved.fullName, 'Asha');
      expect(saved.targetExamYear, DateTime.now().year + 1);
      expect(saved.category, isNull);
      expect(saved.preferredLanguage, 'en');
    });

    testWidgets('ages outside 13-30 get a friendly message', (tester) async {
      await pumpApp(tester);
      await fillProfile(tester, dob: yearsAgo(12));

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.textContaining('students aged 13 to 30'), findsOneWidget);
      expect(signup.savedProfile, isNull);
    });

    testWidgets('an impossible date is rejected', (tester) async {
      await pumpApp(tester);
      await fillProfile(tester, dob: '31/02/2010');

      expect(
        find.text('Enter your date of birth as DD/MM/YYYY'),
        findsOneWidget,
      );
      expect(signup.savedProfile, isNull);
    });

    testWidgets('an API error is shown on the form', (tester) async {
      await pumpApp(tester);
      signup.nextFailure = const SignupFailure('dob_already_set');
      await fillProfile(tester, dob: yearsAgo(16));

      expect(find.textContaining("can't be changed here"), findsOneWidget);
    });
  });

  group('terms', () {
    testWidgets('accepting is possible only after ticking the box', (
      tester,
    ) async {
      signup
        ..status = SignupStatus.needsTerms
        ..isMinor = false;
      await pumpApp(tester);

      final button = find.widgetWithText(FilledButton, 'Accept and continue');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await acceptTerms(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('the placeholder policy opens from the terms step', (
      tester,
    ) async {
      signup.status = SignupStatus.needsTerms;
      await pumpApp(tester);
      await tester.tap(find.text('Read the terms and privacy policy'));
      await tester.pumpAndSettle();

      expect(find.text('Version 2026-10-draft'), findsOneWidget);
      expect(find.textContaining('This is a draft'), findsOneWidget);
    });
  });

  group('parental consent', () {
    setUp(() {
      signup
        ..status = SignupStatus.needsParental
        ..isMinor = true;
    });

    testWidgets('a minor is blocked until a parent consents', (tester) async {
      await pumpApp(tester);
      expect(find.byType(ParentConsentScreen), findsOneWidget);

      await sendToParent(tester, '99999 00006');
      expect(signup.parentCodesSentTo, ['+919999900006']);
      expect(
        find.textContaining("Sunita's phone ending in 0006"),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('parent-code-field')),
        '000000',
      );
      await tester.pumpAndSettle();
      expect(find.text('Wrong code. 4 attempts left.'), findsOneWidget);
      expect(find.byType(ParentConsentScreen), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('parent-code-field')),
        '123456',
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets("the student's own number is rejected", (tester) async {
      await pumpApp(tester);
      await sendToParent(tester, '99999 00001');

      expect(
        find.text("Enter your parent's number, not your own."),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('five wrong codes lock it and ask for a new one', (
      tester,
    ) async {
      await pumpApp(tester);
      await sendToParent(tester, '99999 00006');
      for (var i = 0; i < 5; i++) {
        await tester.enterText(
          find.byKey(const Key('parent-code-field')),
          '00000$i',
        );
        await tester.pumpAndSettle();
      }

      expect(
        find.text('Too many wrong attempts. Send a new code.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('parent-name-field')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the waiting view offers resend after the wait', (
      tester,
    ) async {
      signup.resendDelay = Duration.zero;
      await pumpApp(tester);
      await sendToParent(tester, '99999 00006');
      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();

      expect(signup.parentCodesSentTo, ['+919999900006', '+919999900006']);
      await unmount(tester);
    });

    testWidgets('resend is disabled during the wait', (tester) async {
      await pumpApp(tester);
      await sendToParent(tester, '99999 00006');

      final resend = find.textContaining('Resend code in');
      expect(resend, findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.ancestor(of: resend, matching: find.byType(TextButton)),
            )
            .onPressed,
        isNull,
      );
      await unmount(tester);
    });

    testWidgets("the parent's number can be changed", (tester) async {
      await pumpApp(tester);
      await sendToParent(tester, '99999 00006');
      await tester.tap(find.text("Change parent's number"));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('parent-phone-field')),
        '99999 00007',
      );
      await tester.tap(find.text('Send code to parent'));
      await tester.pumpAndSettle();

      expect(signup.parentCodesSentTo.last, '+919999900007');
      expect(find.textContaining('ending in 0007'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the student can sign out while waiting', (tester) async {
      await pumpApp(tester);
      await sendToParent(tester, '99999 00006');
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.byType(PhoneScreen), findsOneWidget);
    });
  });

  group('home', () {
    testWidgets('withdrawing parental consent blocks the minor again', (
      tester,
    ) async {
      signup
        ..status = SignupStatus.complete
        ..isMinor = true;
      await pumpApp(tester);
      await tester.tap(find.text('Withdraw parental consent'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
      await tester.pumpAndSettle();

      expect(signup.withdrawn, [ConsentType.parental]);
      expect(find.byType(ParentConsentScreen), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('cancelling keeps consent', (tester) async {
      signup
        ..status = SignupStatus.complete
        ..isMinor = false;
      await pumpApp(tester);
      expect(find.text('Withdraw parental consent'), findsNothing);
      await tester.tap(find.text('Withdraw consent to the terms'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(signup.withdrawn, isEmpty);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('the language choice is saved to the profile', (tester) async {
      signup.status = SignupStatus.complete;
      await pumpApp(tester);
      await tester.tap(find.text('ಕನ್ನಡ'));
      await tester.pumpAndSettle();

      expect(profiles.savedLanguages, ['kn']);
    });

    testWidgets('a completed profile restores its language', (tester) async {
      signup.status = SignupStatus.complete;
      profiles.profile = Profile(
        id: 'user-1',
        fullName: 'Asha',
        preferredLanguage: 'kn',
        dateOfBirth: DateTime(2009),
        targetExamYear: 2027,
      );
      await pumpApp(tester);

      expect(find.text('English'), findsOneWidget);
    });
  });

  testWidgets('a failed load can be retried', (tester) async {
    signup.nextFailure = const SignupFailure(SignupFailure.network);
    await pumpApp(tester);
    expect(find.textContaining("Can't reach the server"), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  group('helpers', () {
    test('signupRoute maps each status to its step', () {
      AsyncValue<SignupState?> s(SignupStatus status) =>
          AsyncData(SignupState(status: status));
      expect(signupRoute(s(SignupStatus.needsProfile)), Routes.profile);
      expect(signupRoute(s(SignupStatus.needsTerms)), Routes.terms);
      expect(signupRoute(s(SignupStatus.needsParental)), Routes.parent);
      expect(signupRoute(s(SignupStatus.complete)), isNull);
      expect(signupRoute(const AsyncLoading()), Routes.gate);
    });

    test('parseDate reads DD/MM/YYYY and rejects impossible dates', () {
      expect(parseDate('07/05/2010'), DateTime(2010, 5, 7));
      expect(parseDate('7/5/2010'), DateTime(2010, 5, 7));
      expect(parseDate('29/02/2011'), isNull);
      expect(parseDate('2010-05-07'), isNull);
    });

    test('ageOn counts whole years', () {
      final dob = DateTime(2008, 9, 27);
      expect(ageOn(dob, DateTime(2026, 9, 26)), 17);
      expect(ageOn(dob, DateTime(2026, 9, 27)), 18);
    });
  });
}
