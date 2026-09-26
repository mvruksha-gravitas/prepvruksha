import 'package:core/core.dart';

import '../../l10n/generated/app_localizations.dart';

extension SignupFailureText on SignupFailure {
  String localized(AppLocalizations l10n) => switch (code) {
    'age_out_of_range' => l10n.errorAgeOutOfRange,
    'dob_already_set' => l10n.errorDobAlreadySet,
    'policy_version_outdated' => l10n.errorTermsOutdated,
    'parent_phone_invalid' => l10n.errorParentPhoneInvalid,
    'parent_phone_is_student_phone' => l10n.errorParentPhoneIsYours,
    'resend_too_soon' => l10n.errorResendTooSoon,
    'daily_limit_reached' ||
    'parent_phone_daily_limit_reached' => l10n.errorDailyLimit,
    'code_not_sent' => l10n.errorCodeNotSent,
    'full_name_invalid' ||
    'target_exam_year_invalid' ||
    'category_invalid' ||
    'parent_name_invalid' ||
    'invalid_input' => l10n.errorInvalidInput,
    SignupFailure.network => l10n.errorNetwork,
    _ => l10n.errorUnknown,
  };
}
