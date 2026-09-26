import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PrepVruksha Console'**
  String get appTitle;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff sign-in'**
  String get signInTitle;

  /// No description provided for @signInWith.
  ///
  /// In en, this message translates to:
  /// **'Sign in with'**
  String get signInWith;

  /// No description provided for @signInMethodPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone (one-time code)'**
  String get signInMethodPhone;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get phoneLabel;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a 10-digit Indian mobile number.'**
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
  /// **'We sent a 6-digit code to {phone}.'**
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

  /// No description provided for @changeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get changeNumber;

  /// No description provided for @errorInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code is wrong or has expired. Check it, or ask for a new code.'**
  String get errorInvalidCode;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a few minutes and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get errorNetwork;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnknown;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @checkingAccess.
  ///
  /// In en, this message translates to:
  /// **'Checking your access…'**
  String get checkingAccess;

  /// No description provided for @accessCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t check your access.'**
  String get accessCheckFailed;

  /// No description provided for @noAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'No access'**
  String get noAccessTitle;

  /// No description provided for @noAccessBody.
  ///
  /// In en, this message translates to:
  /// **'This console is for the PrepVruksha content team. Your account ({phone}) has no staff role. Ask a super admin to add you.'**
  String noAccessBody(String phone);

  /// No description provided for @rolesLabel.
  ///
  /// In en, this message translates to:
  /// **'Roles: {roles}'**
  String rolesLabel(String roles);

  /// No description provided for @roleReviewer.
  ///
  /// In en, this message translates to:
  /// **'Reviewer'**
  String get roleReviewer;

  /// No description provided for @roleContentAdmin.
  ///
  /// In en, this message translates to:
  /// **'Content admin'**
  String get roleContentAdmin;

  /// No description provided for @roleSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super admin'**
  String get roleSuperAdmin;

  /// No description provided for @filesTitle.
  ///
  /// In en, this message translates to:
  /// **'Source files'**
  String get filesTitle;

  /// No description provided for @uploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get uploadFile;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @filesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No files yet.'**
  String get filesEmpty;

  /// No description provided for @filesNoneMatch.
  ///
  /// In en, this message translates to:
  /// **'No files match these filters.'**
  String get filesNoneMatch;

  /// No description provided for @filesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load the files.'**
  String get filesLoadFailed;

  /// No description provided for @filterAllStatuses.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get filterAllStatuses;

  /// No description provided for @filterAllRights.
  ///
  /// In en, this message translates to:
  /// **'All rights'**
  String get filterAllRights;

  /// No description provided for @columnFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get columnFile;

  /// No description provided for @columnRights.
  ///
  /// In en, this message translates to:
  /// **'Rights'**
  String get columnRights;

  /// No description provided for @columnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get columnStatus;

  /// No description provided for @columnUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get columnUploaded;

  /// No description provided for @rightsOwnedLicensed.
  ///
  /// In en, this message translates to:
  /// **'Owned / licensed'**
  String get rightsOwnedLicensed;

  /// No description provided for @rightsOwnedLicensedHelp.
  ///
  /// In en, this message translates to:
  /// **'We wrote it or have a licence to publish it.'**
  String get rightsOwnedLicensedHelp;

  /// No description provided for @rightsOfficialPyq.
  ///
  /// In en, this message translates to:
  /// **'Official previous-year paper'**
  String get rightsOfficialPyq;

  /// No description provided for @rightsOfficialPyqHelp.
  ///
  /// In en, this message translates to:
  /// **'An official exam paper (e.g. NTA NEET). Record the exam and year.'**
  String get rightsOfficialPyqHelp;

  /// No description provided for @rightsReferenceOnly.
  ///
  /// In en, this message translates to:
  /// **'Reference only'**
  String get rightsReferenceOnly;

  /// No description provided for @rightsReferenceOnlyHelp.
  ///
  /// In en, this message translates to:
  /// **'Not ours to publish. Used only for similarity checks and ideas. Choose this when unsure.'**
  String get rightsReferenceOnlyHelp;

  /// No description provided for @pyqLabel.
  ///
  /// In en, this message translates to:
  /// **'{exam} {year}'**
  String pyqLabel(String exam, int year);

  /// No description provided for @statusAwaitingUpload.
  ///
  /// In en, this message translates to:
  /// **'Awaiting upload'**
  String get statusAwaitingUpload;

  /// No description provided for @statusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get statusQueued;

  /// No description provided for @statusExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting'**
  String get statusExtracting;

  /// No description provided for @statusParsing.
  ///
  /// In en, this message translates to:
  /// **'Parsing'**
  String get statusParsing;

  /// No description provided for @statusNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get statusNeedsReview;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @uploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload a source file'**
  String get uploadTitle;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose PDF or Word file'**
  String get chooseFile;

  /// No description provided for @chooseAnotherFile.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get chooseAnotherFile;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is larger than 100 MB.'**
  String get fileTooLarge;

  /// No description provided for @fileTypeNotAccepted.
  ///
  /// In en, this message translates to:
  /// **'Only PDF (.pdf) and Word (.docx) files are accepted.'**
  String get fileTypeNotAccepted;

  /// No description provided for @fileSize.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String fileSize(String size);

  /// No description provided for @rightsStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Rights status'**
  String get rightsStatusLabel;

  /// No description provided for @rightsStatusRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the rights status.'**
  String get rightsStatusRequired;

  /// No description provided for @rightsNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Rights note'**
  String get rightsNoteLabel;

  /// No description provided for @rightsNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Where the file comes from and why we may use it'**
  String get rightsNoteHint;

  /// No description provided for @rightsNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Write a rights note.'**
  String get rightsNoteRequired;

  /// No description provided for @pyqExamLabel.
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get pyqExamLabel;

  /// No description provided for @pyqYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get pyqYearLabel;

  /// No description provided for @pyqYearInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a year between 1980 and {max}.'**
  String pyqYearInvalid(int max);

  /// No description provided for @examNeetUg.
  ///
  /// In en, this message translates to:
  /// **'NEET-UG'**
  String get examNeetUg;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @stepHashing.
  ///
  /// In en, this message translates to:
  /// **'Checking the file…'**
  String get stepHashing;

  /// No description provided for @stepRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording the file…'**
  String get stepRecording;

  /// No description provided for @stepUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get stepUploading;

  /// No description provided for @stepConfirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming the upload…'**
  String get stepConfirming;

  /// No description provided for @uploadDone.
  ///
  /// In en, this message translates to:
  /// **'{name} uploaded and queued for import.'**
  String uploadDone(String name);

  /// No description provided for @errorDuplicateFile.
  ///
  /// In en, this message translates to:
  /// **'This exact file was already uploaded.'**
  String get errorDuplicateFile;

  /// No description provided for @errorNotAuthorised.
  ///
  /// In en, this message translates to:
  /// **'Your role can\'t do this.'**
  String get errorNotAuthorised;

  /// No description provided for @errorUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'The upload failed. Try again.'**
  String get errorUploadFailed;

  /// No description provided for @errorUploadIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The upload didn\'t finish. Try again.'**
  String get errorUploadIncomplete;

  /// No description provided for @errorInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Some details are not valid. Check the form.'**
  String get errorInvalidInput;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
