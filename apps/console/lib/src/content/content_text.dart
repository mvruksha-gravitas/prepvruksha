import 'package:core/core.dart';

import '../../l10n/generated/app_localizations.dart';

extension RightsStatusText on RightsStatus {
  String label(AppLocalizations l10n) => switch (this) {
    RightsStatus.ownedLicensed => l10n.rightsOwnedLicensed,
    RightsStatus.officialPyq => l10n.rightsOfficialPyq,
    RightsStatus.referenceOnly => l10n.rightsReferenceOnly,
  };

  String help(AppLocalizations l10n) => switch (this) {
    RightsStatus.ownedLicensed => l10n.rightsOwnedLicensedHelp,
    RightsStatus.officialPyq => l10n.rightsOfficialPyqHelp,
    RightsStatus.referenceOnly => l10n.rightsReferenceOnlyHelp,
  };
}

extension SourceFileStatusText on SourceFileStatus {
  String label(AppLocalizations l10n) => switch (this) {
    SourceFileStatus.awaitingUpload => l10n.statusAwaitingUpload,
    SourceFileStatus.queued => l10n.statusQueued,
    SourceFileStatus.extracting => l10n.statusExtracting,
    SourceFileStatus.parsing => l10n.statusParsing,
    SourceFileStatus.needsReview => l10n.statusNeedsReview,
    SourceFileStatus.done => l10n.statusDone,
    SourceFileStatus.failed => l10n.statusFailed,
  };
}

String examLabel(String code, AppLocalizations l10n) => switch (code) {
  'NEET_UG' => l10n.examNeetUg,
  _ => code,
};

String megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

extension ApiFailureText on ApiFailure {
  String localized(AppLocalizations l10n) => switch (code) {
    'duplicate_file' => l10n.errorDuplicateFile,
    'not_authorised' => l10n.errorNotAuthorised,
    'upload_failed' => l10n.errorUploadFailed,
    'upload_missing' || 'upload_size_mismatch' => l10n.errorUploadIncomplete,
    ApiFailure.invalidInput ||
    'rights_note_required' ||
    'pyq_exam_and_year_required' ||
    'pyq_year_invalid' => l10n.errorInvalidInput,
    ApiFailure.network => l10n.errorNetwork,
    _ => l10n.errorUnknown,
  };
}
