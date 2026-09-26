// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PrepVruksha Console';

  @override
  String get signInTitle => 'Staff sign-in';

  @override
  String get signInWith => 'Sign in with';

  @override
  String get signInMethodPhone => 'Phone (one-time code)';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phoneInvalid => 'Enter a 10-digit Indian mobile number.';

  @override
  String get sendCode => 'Send code';

  @override
  String get otpTitle => 'Enter the code';

  @override
  String otpSentTo(String phone) {
    return 'We sent a 6-digit code to $phone.';
  }

  @override
  String get otpLabel => '6-digit code';

  @override
  String get verify => 'Verify';

  @override
  String get changeNumber => 'Change number';

  @override
  String get errorInvalidCode =>
      'That code is wrong or has expired. Check it, or ask for a new code.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Please wait a few minutes and try again.';

  @override
  String get errorNetwork =>
      'No connection. Check your internet and try again.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get signOut => 'Sign out';

  @override
  String get retry => 'Retry';

  @override
  String get checkingAccess => 'Checking your access…';

  @override
  String get accessCheckFailed => 'We couldn\'t check your access.';

  @override
  String get noAccessTitle => 'No access';

  @override
  String noAccessBody(String phone) {
    return 'This console is for the PrepVruksha content team. Your account ($phone) has no staff role. Ask a super admin to add you.';
  }

  @override
  String rolesLabel(String roles) {
    return 'Roles: $roles';
  }

  @override
  String get roleReviewer => 'Reviewer';

  @override
  String get roleContentAdmin => 'Content admin';

  @override
  String get roleSuperAdmin => 'Super admin';

  @override
  String get filesTitle => 'Source files';

  @override
  String get uploadFile => 'Upload file';

  @override
  String get refresh => 'Refresh';

  @override
  String get filesEmpty => 'No files yet.';

  @override
  String get filesNoneMatch => 'No files match these filters.';

  @override
  String get filesLoadFailed => 'We couldn\'t load the files.';

  @override
  String get filterAllStatuses => 'All statuses';

  @override
  String get filterAllRights => 'All rights';

  @override
  String get columnFile => 'File';

  @override
  String get columnRights => 'Rights';

  @override
  String get columnStatus => 'Status';

  @override
  String get columnUploaded => 'Uploaded';

  @override
  String get rightsOwnedLicensed => 'Owned / licensed';

  @override
  String get rightsOwnedLicensedHelp =>
      'We wrote it or have a licence to publish it.';

  @override
  String get rightsOfficialPyq => 'Official previous-year paper';

  @override
  String get rightsOfficialPyqHelp =>
      'An official exam paper (e.g. NTA NEET). Record the exam and year.';

  @override
  String get rightsReferenceOnly => 'Reference only';

  @override
  String get rightsReferenceOnlyHelp =>
      'Not ours to publish. Used only for similarity checks and ideas. Choose this when unsure.';

  @override
  String pyqLabel(String exam, int year) {
    return '$exam $year';
  }

  @override
  String get statusAwaitingUpload => 'Awaiting upload';

  @override
  String get statusQueued => 'Queued';

  @override
  String get statusExtracting => 'Extracting';

  @override
  String get statusParsing => 'Parsing';

  @override
  String get statusNeedsReview => 'Needs review';

  @override
  String get statusDone => 'Done';

  @override
  String get statusFailed => 'Failed';

  @override
  String get uploadTitle => 'Upload a source file';

  @override
  String get chooseFile => 'Choose PDF or Word file';

  @override
  String get chooseAnotherFile => 'Choose another file';

  @override
  String get fileTooLarge => 'The file is larger than 100 MB.';

  @override
  String get fileTypeNotAccepted =>
      'Only PDF (.pdf) and Word (.docx) files are accepted.';

  @override
  String fileSize(String size) {
    return '$size MB';
  }

  @override
  String get rightsStatusLabel => 'Rights status';

  @override
  String get rightsStatusRequired => 'Choose the rights status.';

  @override
  String get rightsNoteLabel => 'Rights note';

  @override
  String get rightsNoteHint =>
      'Where the file comes from and why we may use it';

  @override
  String get rightsNoteRequired => 'Write a rights note.';

  @override
  String get pyqExamLabel => 'Exam';

  @override
  String get pyqYearLabel => 'Year';

  @override
  String pyqYearInvalid(int max) {
    return 'Enter a year between 1980 and $max.';
  }

  @override
  String get examNeetUg => 'NEET-UG';

  @override
  String get cancel => 'Cancel';

  @override
  String get upload => 'Upload';

  @override
  String get stepHashing => 'Checking the file…';

  @override
  String get stepRecording => 'Recording the file…';

  @override
  String get stepUploading => 'Uploading…';

  @override
  String get stepConfirming => 'Confirming the upload…';

  @override
  String uploadDone(String name) {
    return '$name uploaded and queued for import.';
  }

  @override
  String get errorDuplicateFile => 'This exact file was already uploaded.';

  @override
  String get errorNotAuthorised => 'Your role can\'t do this.';

  @override
  String get errorUploadFailed => 'The upload failed. Try again.';

  @override
  String get errorUploadIncomplete => 'The upload didn\'t finish. Try again.';

  @override
  String get errorInvalidInput => 'Some details are not valid. Check the form.';
}
