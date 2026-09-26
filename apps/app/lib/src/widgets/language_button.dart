import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../providers.dart';

/// App-bar button that switches between English and Kannada.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  /// Keeps the button clear of the DEBUG ribbon in the top-right corner,
  /// which is drawn only in debug builds.
  static const _debugBannerClearance = 48.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        end: kDebugMode ? _debugBannerClearance : 0,
      ),
      child: TextButton(
        onPressed: () => ref
            .read(localeProvider.notifier)
            .toggle(Localizations.localeOf(context)),
        child: Text(AppLocalizations.of(context).switchLanguage),
      ),
    );
  }
}
