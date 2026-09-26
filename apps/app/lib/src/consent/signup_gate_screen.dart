import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../auth/auth.dart';
import 'consent_providers.dart';
import 'signup_failure_text.dart';

/// Shown while the signup state loads, or when it can't be loaded.
class SignupGateScreen extends ConsumerWidget {
  const SignupGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signup = ref.watch(signupStateProvider);
    final error = signup.hasError && !signup.isLoading ? signup.error : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error is SignupFailure
                            ? error.localized(l10n)
                            : l10n.errorUnknown,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () =>
                            ref.read(signupStateProvider.notifier).retry(),
                        child: Text(l10n.retry),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(authRepositoryProvider).signOut(),
                        child: Text(l10n.signOut),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
