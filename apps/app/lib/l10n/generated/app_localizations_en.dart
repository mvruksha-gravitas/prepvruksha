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
  String get signOut => 'Sign out';

  @override
  String get retry => 'Try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueButton => 'Continue';

  @override
  String get profileTitle => 'About you';

  @override
  String get profileIntro => 'We use these details to set up your preparation.';

  @override
  String get profileNameLabel => 'Full name';

  @override
  String get profileNameRequired => 'Enter your name';

  @override
  String get profileDobLabel => 'Date of birth';

  @override
  String get profileDobHint => 'DD/MM/YYYY';

  @override
  String get profileDobInvalid => 'Enter your date of birth as DD/MM/YYYY';

  @override
  String get profileDobOnce =>
      'Check this carefully: your date of birth can\'t be changed later.';

  @override
  String get profileExamYearLabel => 'NEET exam year';

  @override
  String get profileExamYearRequired => 'Choose your exam year';

  @override
  String get profileExamYearsLoadFailed =>
      'Couldn\'t load the exam years. Check your connection and try again.';

  @override
  String get profileExamYearsUnavailable =>
      'The next NEET exam date isn\'t available yet, so signup is paused. Please try again later.';

  @override
  String get profileCategoryLabel => 'Category (optional)';

  @override
  String get profileCategoryHelp =>
      'Needed later only for the college predictor.';

  @override
  String get categoryNone => 'Prefer not to say';

  @override
  String get categoryGeneral => 'General';

  @override
  String get categoryEws => 'EWS';

  @override
  String get categoryObcNcl => 'OBC (non-creamy layer)';

  @override
  String get categorySc => 'SC';

  @override
  String get categorySt => 'ST';

  @override
  String get profileLanguageLabel => 'App language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKannada => 'ಕನ್ನಡ';

  @override
  String get termsTitle => 'Terms and privacy';

  @override
  String get termsIntro =>
      'Before you start, please read and accept our terms of use and privacy policy.';

  @override
  String get termsRead => 'Read the terms and privacy policy';

  @override
  String get termsAgree =>
      'I have read and agree to the terms of use and privacy policy';

  @override
  String get termsAccept => 'Accept and continue';

  @override
  String get policyTitle => 'Terms and privacy policy';

  @override
  String policyVersion(String version) {
    return 'Version $version';
  }

  @override
  String get policyPlaceholderBody =>
      'This is a draft. The final terms of use and privacy policy are being prepared and will appear here before PrepVruksha opens to students.\n\nIn short: we use your phone number to sign you in, and your answers and results to show your progress. Students under 18 need a parent\'s or guardian\'s permission. We never show targeted advertising to students under 18, never track their behaviour for advertising, and never send your name or phone number to AI services. You can withdraw your consent at any time.';

  @override
  String get parentTitle => 'Parent\'s permission';

  @override
  String get parentIntro =>
      'You are under 18, so a parent or guardian must allow you to use PrepVruksha. We\'ll send a code to their phone.';

  @override
  String get parentNameLabel => 'Parent or guardian\'s name';

  @override
  String get parentNameRequired => 'Enter your parent\'s or guardian\'s name';

  @override
  String get parentPhoneLabel => 'Parent\'s mobile number';

  @override
  String get parentSendCode => 'Send code to parent';

  @override
  String parentCodeSent(String name, String last4) {
    return 'We sent a code to $name\'s phone ending in $last4. Ask them for the code and enter it here.';
  }

  @override
  String get parentCodeLabel => 'Code from your parent';

  @override
  String get parentConsentNote =>
      'By sharing this code, your parent or guardian agrees to let you use PrepVruksha under the terms and privacy policy.';

  @override
  String parentCodeWrong(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wrong code. $count attempts left.',
      one: 'Wrong code. 1 attempt left.',
    );
    return '$_temp0';
  }

  @override
  String get parentCodeLocked => 'Too many wrong attempts. Send a new code.';

  @override
  String get parentCodeExpired => 'The code has expired. Send a new code.';

  @override
  String get parentChangeNumber => 'Change parent\'s number';

  @override
  String get parentBackToCode => 'Back to entering the code';

  @override
  String get privacyTitle => 'Privacy and consent';

  @override
  String get withdrawTerms => 'Withdraw consent to the terms';

  @override
  String get withdrawParental => 'Withdraw parental consent';

  @override
  String get withdrawConfirmTitle => 'Withdraw consent?';

  @override
  String get withdrawConfirmBody =>
      'You won\'t be able to use PrepVruksha until consent is given again. Your record of consent is kept.';

  @override
  String get withdrawConfirm => 'Withdraw';

  @override
  String get errorAgeOutOfRange =>
      'PrepVruksha is for students aged 13 to 30. Check your date of birth. If it is correct, we\'re sorry, you can\'t sign up yet.';

  @override
  String get errorDobAlreadySet =>
      'Your date of birth is already saved and can\'t be changed here. Contact support if it is wrong.';

  @override
  String get errorInvalidInput =>
      'Some details are not valid. Check them and try again.';

  @override
  String get errorTermsOutdated =>
      'The terms have been updated. Please read and accept them again.';

  @override
  String get errorParentPhoneInvalid =>
      'Enter a valid 10-digit Indian mobile number';

  @override
  String get errorParentPhoneIsYours =>
      'Enter your parent\'s number, not your own.';

  @override
  String get errorResendTooSoon =>
      'Please wait a minute before asking for another code.';

  @override
  String get errorDailyLimit =>
      'Too many codes sent today. Try again tomorrow.';

  @override
  String get errorCodeNotSent =>
      'We couldn\'t send the code. Try again in a minute.';
}
