import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import 'consent_providers.dart';

/// Terms of use and privacy policy.
///
/// PLACEHOLDER: the final text comes from a lawyer before launch (launch
/// blocker in docs/STATUS.md), versioned in `policy_versions`.
class PolicyScreen extends ConsumerWidget {
  const PolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final version = ref.watch(signupStateProvider).value?.termsVersion;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.policyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (version != null) ...[
              Text(
                l10n.policyVersion(version),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 16),
            ],
            Text(l10n.policyPlaceholderBody),
          ],
        ),
      ),
    );
  }
}
