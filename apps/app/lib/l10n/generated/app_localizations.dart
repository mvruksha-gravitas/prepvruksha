import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kn.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kn'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PrepVruksha'**
  String get appTitle;

  /// Button that switches the app to the other language; shown in that language.
  ///
  /// In en, this message translates to:
  /// **'ಕನ್ನಡ'**
  String get switchLanguage;

  /// No description provided for @phoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your phone'**
  String get phoneTitle;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get phoneLabel;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit Indian mobile number'**
  String get phoneInvalid;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get otpTitle;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {phone}'**
  String otpSentTo(String phone);

  /// No description provided for @otpLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get otpLabel;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @resend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resend;

  /// No description provided for @changeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get changeNumber;

  /// No description provided for @errorInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code is incorrect or has expired. Check it or request a new one.'**
  String get errorInvalidCode;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnknown;

  /// No description provided for @homeWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get homeWelcome;

  /// No description provided for @homeSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {phone}'**
  String homeSignedInAs(String phone);

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get profileTitle;

  /// No description provided for @profileIntro.
  ///
  /// In en, this message translates to:
  /// **'We use these details to set up your preparation.'**
  String get profileIntro;

  /// No description provided for @profileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get profileNameLabel;

  /// No description provided for @profileNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get profileNameRequired;

  /// No description provided for @profileDobLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get profileDobLabel;

  /// Date format hint; keep DD/MM/YYYY in Latin letters.
  ///
  /// In en, this message translates to:
  /// **'DD/MM/YYYY'**
  String get profileDobHint;

  /// No description provided for @profileDobInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter your date of birth as DD/MM/YYYY'**
  String get profileDobInvalid;

  /// No description provided for @profileDobOnce.
  ///
  /// In en, this message translates to:
  /// **'Check this carefully: your date of birth can\'t be changed later.'**
  String get profileDobOnce;

  /// No description provided for @profileExamYearLabel.
  ///
  /// In en, this message translates to:
  /// **'NEET exam year'**
  String get profileExamYearLabel;

  /// No description provided for @profileExamYearRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose your exam year'**
  String get profileExamYearRequired;

  /// No description provided for @profileCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get profileCategoryLabel;

  /// No description provided for @profileCategoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Needed later only for the college predictor.'**
  String get profileCategoryHelp;

  /// No description provided for @categoryNone.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get categoryNone;

  /// No description provided for @categoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get categoryGeneral;

  /// No description provided for @categoryEws.
  ///
  /// In en, this message translates to:
  /// **'EWS'**
  String get categoryEws;

  /// No description provided for @categoryObcNcl.
  ///
  /// In en, this message translates to:
  /// **'OBC (non-creamy layer)'**
  String get categoryObcNcl;

  /// No description provided for @categorySc.
  ///
  /// In en, this message translates to:
  /// **'SC'**
  String get categorySc;

  /// No description provided for @categorySt.
  ///
  /// In en, this message translates to:
  /// **'ST'**
  String get categorySt;

  /// No description provided for @profileLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get profileLanguageLabel;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Always shown in Kannada.
  ///
  /// In en, this message translates to:
  /// **'ಕನ್ನಡ'**
  String get languageKannada;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms and privacy'**
  String get termsTitle;

  /// No description provided for @termsIntro.
  ///
  /// In en, this message translates to:
  /// **'Before you start, please read and accept our terms of use and privacy policy.'**
  String get termsIntro;

  /// No description provided for @termsRead.
  ///
  /// In en, this message translates to:
  /// **'Read the terms and privacy policy'**
  String get termsRead;

  /// No description provided for @termsAgree.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the terms of use and privacy policy'**
  String get termsAgree;

  /// No description provided for @termsAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept and continue'**
  String get termsAccept;

  /// No description provided for @policyTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms and privacy policy'**
  String get policyTitle;

  /// No description provided for @policyVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String policyVersion(String version);

  /// No description provided for @policyPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'This is a draft. The final terms of use and privacy policy are being prepared and will appear here before PrepVruksha opens to students.\n\nIn short: we use your phone number to sign you in, and your answers and results to show your progress. Students under 18 need a parent\'s or guardian\'s permission. We never show targeted advertising to students under 18, never track their behaviour for advertising, and never send your name or phone number to AI services. You can withdraw your consent at any time.'**
  String get policyPlaceholderBody;

  /// No description provided for @parentTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent\'s permission'**
  String get parentTitle;

  /// No description provided for @parentIntro.
  ///
  /// In en, this message translates to:
  /// **'You are under 18, so a parent or guardian must allow you to use PrepVruksha. We\'ll send a code to their phone.'**
  String get parentIntro;

  /// No description provided for @parentNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Parent or guardian\'s name'**
  String get parentNameLabel;

  /// No description provided for @parentNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your parent\'s or guardian\'s name'**
  String get parentNameRequired;

  /// No description provided for @parentPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Parent\'s mobile number'**
  String get parentPhoneLabel;

  /// No description provided for @parentSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code to parent'**
  String get parentSendCode;

  /// No description provided for @parentCodeSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {name}\'s phone ending in {last4}. Ask them for the code and enter it here.'**
  String parentCodeSent(String name, String last4);

  /// No description provided for @parentCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code from your parent'**
  String get parentCodeLabel;

  /// No description provided for @parentConsentNote.
  ///
  /// In en, this message translates to:
  /// **'By sharing this code, your parent or guardian agrees to let you use PrepVruksha under the terms and privacy policy.'**
  String get parentConsentNote;

  /// No description provided for @parentCodeWrong.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Wrong code. 1 attempt left.} other{Wrong code. {count} attempts left.}}'**
  String parentCodeWrong(int count);

  /// No description provided for @parentCodeLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong attempts. Send a new code.'**
  String get parentCodeLocked;

  /// No description provided for @parentCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'The code has expired. Send a new code.'**
  String get parentCodeExpired;

  /// No description provided for @parentChangeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change parent\'s number'**
  String get parentChangeNumber;

  /// No description provided for @parentBackToCode.
  ///
  /// In en, this message translates to:
  /// **'Back to entering the code'**
  String get parentBackToCode;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy and consent'**
  String get privacyTitle;

  /// No description provided for @withdrawTerms.
  ///
  /// In en, this message translates to:
  /// **'Withdraw consent to the terms'**
  String get withdrawTerms;

  /// No description provided for @withdrawParental.
  ///
  /// In en, this message translates to:
  /// **'Withdraw parental consent'**
  String get withdrawParental;

  /// No description provided for @withdrawConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdraw consent?'**
  String get withdrawConfirmTitle;

  /// No description provided for @withdrawConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t be able to use PrepVruksha until consent is given again. Your record of consent is kept.'**
  String get withdrawConfirmBody;

  /// No description provided for @withdrawConfirm.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdrawConfirm;

  /// No description provided for @errorAgeOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'PrepVruksha is for students aged 13 to 30. Check your date of birth. If it is correct, we\'re sorry, you can\'t sign up yet.'**
  String get errorAgeOutOfRange;

  /// No description provided for @errorDobAlreadySet.
  ///
  /// In en, this message translates to:
  /// **'Your date of birth is already saved and can\'t be changed here. Contact support if it is wrong.'**
  String get errorDobAlreadySet;

  /// No description provided for @errorInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Some details are not valid. Check them and try again.'**
  String get errorInvalidInput;

  /// No description provided for @errorTermsOutdated.
  ///
  /// In en, this message translates to:
  /// **'The terms have been updated. Please read and accept them again.'**
  String get errorTermsOutdated;

  /// No description provided for @errorParentPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit Indian mobile number'**
  String get errorParentPhoneInvalid;

  /// No description provided for @errorParentPhoneIsYours.
  ///
  /// In en, this message translates to:
  /// **'Enter your parent\'s number, not your own.'**
  String get errorParentPhoneIsYours;

  /// No description provided for @errorResendTooSoon.
  ///
  /// In en, this message translates to:
  /// **'Please wait a minute before asking for another code.'**
  String get errorResendTooSoon;

  /// No description provided for @errorDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many codes sent today. Try again tomorrow.'**
  String get errorDailyLimit;

  /// No description provided for @errorCodeNotSent.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t send the code. Try again in a minute.'**
  String get errorCodeNotSent;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kn'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'kn':
      return AppLocalizationsKn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
