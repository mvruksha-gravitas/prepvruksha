// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PrepVruksha';

  @override
  String get switchLanguage => 'ಕನ್ನಡ';

  @override
  String get phoneTitle => 'Sign in with your phone';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phoneInvalid => 'Enter a valid 10-digit Indian mobile number';

  @override
  String get sendCode => 'Send code';

  @override
  String get otpTitle => 'Enter the code';

  @override
  String otpSentTo(String phone) {
    return 'We sent a 6-digit code to $phone';
  }

  @override
  String get otpLabel => '6-digit code';

  @override
  String get verify => 'Verify';

  @override
  String resendIn(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String get resend => 'Resend code';

  @override
  String get changeNumber => 'Change number';

  @override
  String get errorInvalidCode =>
      'That code is incorrect or has expired. Check it or request a new one.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get errorNetwork =>
      'Can\'t reach the server. Check your connection and try again.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get homeWelcome => 'Welcome';

  @override
  String homeSignedInAs(String phone) {
    return 'Signed in as $phone';
  }

  @override
  String get homeProfileIncomplete => 'Complete your profile to get started.';

  @override
  String get signOut => 'Sign out';
}
