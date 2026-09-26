import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../l10n/generated/app_localizations.dart';
import '../providers.dart';
import '../router.dart';
import '../widgets/language_button.dart';
import 'signup_failure_text.dart';

/// Signup step 2: accept the current terms of use and privacy policy.
class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen({super.key});

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    final l10n = AppLocalizations.of(context);
    final version = ref.read(signupStateProvider).value?.termsVersion;
    if (version == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(signupStateProvider.notifier).acceptTerms(version);
    } on SignupFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.localized(l10n));
      // A newer version was published: reload it and ask again.
      if (e.code == 'policy_version_outdated') {
        setState(() => _agreed = false);
        ref.read(signupStateProvider.notifier).retry();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.termsTitle),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(l10n.termsIntro),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => context.push(Routes.policy),
                child: Text(l10n.termsRead),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('terms-checkbox'),
              value: _agreed,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.termsAgree),
              onChanged: (v) => setState(() => _agreed = v ?? false),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            BusyButton(
              label: l10n.termsAccept,
              busy: _busy,
              onPressed: _agreed ? _accept : null,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: Text(l10n.signOut),
            ),
          ],
        ),
      ),
    );
  }
}
