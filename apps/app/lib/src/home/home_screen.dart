import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../providers.dart';
import '../signup/signup_failure_text.dart';
import '../widgets/language_button.dart';

/// Placeholder home screen until the student dashboard slice. Reached only
/// when signup is complete.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authStateProvider).value;
    final profile = ref.watch(ownProfileProvider).value;
    final isMinor = ref.watch(signupStateProvider).value?.isMinor ?? false;
    final phone = PhoneNumber.tryParse(user?.phone ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              profile?.fullName ?? l10n.homeWelcome,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (phone != null) ...[
              const SizedBox(height: 8),
              Text(l10n.homeSignedInAs(phone.display)),
            ],
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: Text(l10n.signOut),
            ),
            const SizedBox(height: 40),
            Text(
              l10n.privacyTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _withdraw(context, ref, ConsentType.terms),
              child: Text(l10n.withdrawTerms),
            ),
            if (isMinor)
              TextButton(
                onPressed: () => _withdraw(context, ref, ConsentType.parental),
                child: Text(l10n.withdrawParental),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    ConsentType type,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.withdrawConfirmTitle),
        content: Text(l10n.withdrawConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.withdrawConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      // On success the router sends the user back to the consent step.
      await ref.read(signupStateProvider.notifier).withdrawConsent(type);
    } on SignupFailure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.localized(l10n))));
      }
    }
  }
}
