import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../providers.dart';

/// App-bar button that switches between English and Kannada.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => ref
          .read(localeProvider.notifier)
          .toggle(Localizations.localeOf(context)),
      child: Text(AppLocalizations.of(context).switchLanguage),
    );
  }
}
