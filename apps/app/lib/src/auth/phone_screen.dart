import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../l10n/generated/app_localizations.dart';
import '../providers.dart';
import '../router.dart';
import '../widgets/language_button.dart';
import 'auth_failure_text.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final phone = PhoneNumber.tryParse(_controller.text);
    if (phone == null) {
      setState(() => _error = l10n.phoneInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone);
      if (mounted) await context.push(Routes.otp, extra: phone);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.localized(l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              l10n.phoneTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('phone-field'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: InputDecoration(
                labelText: l10n.phoneLabel,
                prefixText: '+91 ',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            BusyButton(label: l10n.sendCode, busy: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
