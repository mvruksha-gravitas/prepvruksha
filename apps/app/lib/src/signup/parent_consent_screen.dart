import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../l10n/generated/app_localizations.dart';
import '../providers.dart';
import '../widgets/language_button.dart';
import 'signup_failure_text.dart';

/// Signup step 3 (under 18 only): a parent or guardian gives consent by
/// telling the student the code sent to the parent's phone. The student is
/// blocked until then; from the waiting view they can resend the code,
/// change the parent's number, or sign out.
class ParentConsentScreen extends ConsumerStatefulWidget {
  const ParentConsentScreen({super.key});

  static const codeLength = 6;

  @override
  ConsumerState<ParentConsentScreen> createState() =>
      _ParentConsentScreenState();
}

class _ParentConsentScreenState extends ConsumerState<ParentConsentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();

  /// Showing the parent form although a code is pending (change number).
  bool _editing = false;
  bool _busy = false;
  String? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Keeps the resend countdown current.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _name.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on SignupFailure catch (e) {
      if (mounted) setState(() => _error = e.localized(l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    await _request(_name.text, PhoneNumber.tryParse(_phone.text)!);
  }

  Future<void> _request(String parentName, PhoneNumber parentPhone) =>
      _run(() async {
        await ref
            .read(signupStateProvider.notifier)
            .startParentalConsent(
              parentName: parentName,
              parentPhone: parentPhone.e164,
            );
        _code.clear();
        if (mounted) setState(() => _editing = false);
      });

  /// Resends to the number entered on this device; after an app restart the
  /// full number isn't known here, so the form opens to enter it again.
  Future<void> _resend(PendingParentRequest pending) async {
    final phone = PhoneNumber.tryParse(_phone.text);
    if (phone == null) {
      _name.text = pending.parentName;
      setState(() => _editing = true);
      return;
    }
    await _request(pending.parentName, phone);
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    final code = _code.text;
    if (code.length != ParentConsentScreen.codeLength) return;
    await _run(() async {
      final outcome = await ref
          .read(signupStateProvider.notifier)
          .verifyParentCode(code);
      // verified / not_required: the router leaves this screen.
      final message = switch (outcome.result) {
        ParentCodeResult.invalid => l10n.parentCodeWrong(
          outcome.attemptsLeft ?? 0,
        ),
        ParentCodeResult.locked => l10n.parentCodeLocked,
        ParentCodeResult.expired ||
        ParentCodeResult.noPendingRequest => l10n.parentCodeExpired,
        ParentCodeResult.verified || ParentCodeResult.notRequired => null,
      };
      if (message != null) {
        _code.clear();
        if (mounted) setState(() => _error = message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pending = ref.watch(signupStateProvider).value?.pendingRequest;
    final waiting = pending != null && !_editing;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.parentTitle),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (waiting) ..._codeView(l10n, pending) else ..._formView(l10n),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                key: const Key('parent-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            if (waiting)
              BusyButton(label: l10n.verify, busy: _busy, onPressed: _verify)
            else
              BusyButton(
                label: l10n.parentSendCode,
                busy: _busy,
                onPressed: _send,
              ),
            const SizedBox(height: 8),
            if (waiting) ...[
              _resendButton(l10n, pending),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _editing = true;
                        _error = null;
                        if (_name.text.isEmpty) _name.text = pending.parentName;
                      }),
                child: Text(l10n.parentChangeNumber),
              ),
            ] else if (pending != null)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _editing = false),
                child: Text(l10n.parentBackToCode),
              ),
            TextButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: Text(l10n.signOut),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _formView(AppLocalizations l10n) => [
    Text(l10n.parentIntro),
    const SizedBox(height: 24),
    Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            key: const Key('parent-name-field'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(120)],
            decoration: InputDecoration(labelText: l10n.parentNameLabel),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? l10n.parentNameRequired : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('parent-phone-field'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: InputDecoration(
              labelText: l10n.parentPhoneLabel,
              prefixText: '+91 ',
            ),
            validator: (v) => PhoneNumber.tryParse(v ?? '') == null
                ? l10n.errorParentPhoneInvalid
                : null,
          ),
        ],
      ),
    ),
  ];

  List<Widget> _codeView(
    AppLocalizations l10n,
    PendingParentRequest pending,
  ) => [
    Text(l10n.parentCodeSent(pending.parentName, pending.parentPhoneLast4)),
    const SizedBox(height: 24),
    TextField(
      key: const Key('parent-code-field'),
      controller: _code,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(ParentConsentScreen.codeLength),
      ],
      decoration: InputDecoration(labelText: l10n.parentCodeLabel),
      onChanged: (value) {
        if (value.length == ParentConsentScreen.codeLength) _verify();
      },
    ),
    const SizedBox(height: 8),
    Text(l10n.parentConsentNote, style: Theme.of(context).textTheme.bodySmall),
  ];

  Widget _resendButton(AppLocalizations l10n, PendingParentRequest pending) {
    final wait = pending.resendAvailableAt.difference(DateTime.now()).inSeconds;
    return TextButton(
      onPressed: _busy || wait > 0 ? null : () => _resend(pending),
      child: Text(wait > 0 ? l10n.resendIn(wait) : l10n.resend),
    );
  }
}
