import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepvruksha/src/app.dart';
import 'package:prepvruksha/src/auth/otp_screen.dart';
import 'package:prepvruksha/src/auth/phone_screen.dart';
import 'package:prepvruksha/src/home/home_screen.dart';
import 'package:prepvruksha/src/providers.dart';

import 'fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;

  setUp(() {
    auth = FakeAuthRepository();
    profiles = FakeProfileRepository();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(profiles),
        ],
        child: const PrepVrukshaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Removes the app so the OTP resend timer is cancelled before the test ends.
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  Future<void> goToOtp(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('phone-field')), '99999 00001');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
  }

  testWidgets('a signed-out user sees the phone screen', (tester) async {
    await pumpApp(tester);
    expect(find.byType(PhoneScreen), findsOneWidget);
  });

  testWidgets('an invalid number shows an error and sends nothing', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('phone-field')), '12345');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a valid 10-digit Indian mobile number'),
      findsOneWidget,
    );
    expect(auth.sentTo, isEmpty);
  });

  testWidgets('a rate-limit error on send is explained', (tester) async {
    auth.nextSendFailure = const AuthFailure(AuthFailureCode.rateLimited);
    await pumpApp(tester);
    await goToOtp(tester);

    expect(find.byType(PhoneScreen), findsOneWidget);
    expect(find.textContaining('Too many attempts'), findsOneWidget);
  });

  testWidgets('a valid number sends a code and opens the OTP screen', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToOtp(tester);

    expect(auth.sentTo.single.e164, '+919999900001');
    expect(find.byType(OtpScreen), findsOneWidget);
    expect(
      find.text('We sent a 6-digit code to +91 99999 00001'),
      findsOneWidget,
    );
    expect(find.text('Resend code in 30s'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a wrong code shows an error and stays on the OTP screen', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToOtp(tester);
    await tester.enterText(find.byKey(const Key('otp-field')), '000000');
    await tester.pumpAndSettle();

    expect(find.byType(OtpScreen), findsOneWidget);
    expect(find.textContaining('incorrect or has expired'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the right code signs in, and sign-out returns to login', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToOtp(tester);
    await tester.enterText(find.byKey(const Key('otp-field')), '123456');
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Signed in as +91 99999 00001'), findsOneWidget);
    expect(find.text('Complete your profile to get started.'), findsNothing);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneScreen), findsOneWidget);
  });

  testWidgets('the language button switches to Kannada', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('ಕನ್ನಡ'));
    await tester.pumpAndSettle();

    expect(find.text('ಕೋಡ್ ಕಳುಹಿಸಿ'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });
}
