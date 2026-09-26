import 'package:core/core.dart';

import '../../l10n/generated/app_localizations.dart';

extension AuthFailureText on AuthFailure {
  String localized(AppLocalizations l10n) => switch (code) {
    AuthFailureCode.invalidCode => l10n.errorInvalidCode,
    AuthFailureCode.rateLimited => l10n.errorRateLimited,
    AuthFailureCode.network => l10n.errorNetwork,
    AuthFailureCode.unknown => l10n.errorUnknown,
  };
}
