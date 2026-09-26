import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../providers.dart';
import '../widgets/language_button.dart';

/// Placeholder home screen until the student dashboard slice.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authStateProvider).value;
    final profile = ref.watch(ownProfileProvider).value;
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
            if (profile != null && !profile.isComplete) ...[
              const SizedBox(height: 16),
              Text(l10n.homeProfileIncomplete),
            ],
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: Text(l10n.signOut),
            ),
          ],
        ),
      ),
    );
  }
}
