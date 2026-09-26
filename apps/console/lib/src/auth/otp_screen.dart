import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../l10n/generated/app_localizations.dart';
import 'auth_failure_text.dart';
import 'auth_providers.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final PhoneNumber phone;

  static const codeLength = 6;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // On success the router moves on, so nothing else to do here.
  Future<void> _verify() async {
    final code = _controller.text;
    if (code.length != OtpScreen.codeLength || _busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyOtp(widget.phone, code);
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
      appBar: AppBar(title: Text(l10n.otpTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(l10n.otpSentTo(widget.phone.display)),
              const SizedBox(height: 24),
              TextField(
                key: const Key('otp-field'),
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(OtpScreen.codeLength),
                ],
                decoration: InputDecoration(
                  labelText: l10n.otpLabel,
                  errorText: _error,
                  errorMaxLines: 3,
                ),
                onChanged: (value) {
                  if (value.length == OtpScreen.codeLength) _verify();
                },
              ),
              const SizedBox(height: 24),
              BusyButton(label: l10n.verify, busy: _busy, onPressed: _verify),
              TextButton(
                onPressed: _busy ? null : () => context.pop(),
                child: Text(l10n.changeNumber),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
