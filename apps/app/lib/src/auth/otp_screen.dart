import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../l10n/generated/app_localizations.dart';
import 'auth_providers.dart';
import 'auth_failure_text.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final PhoneNumber phone;

  static const codeLength = 6;
  static const resendDelay = Duration(seconds: 30);

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = OtpScreen.resendDelay.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) timer.cancel();
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.localized(l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // On success the router redirects to home, so nothing else to do here.
  Future<void> _verify() async {
    final code = _controller.text;
    if (code.length != OtpScreen.codeLength) return;
    await _run(
      () => ref.read(authRepositoryProvider).verifyOtp(widget.phone, code),
    );
  }

  Future<void> _resend() async {
    await _run(() async {
      await ref.read(authRepositoryProvider).sendOtp(widget.phone);
      _controller.clear();
      _startResendTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.otpTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(l10n.otpSentTo(widget.phone.display)),
            const SizedBox(height: 24),
            TextField(
              key: const Key('otp-field'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
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
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy || _secondsLeft > 0 ? null : _resend,
              child: Text(
                _secondsLeft > 0 ? l10n.resendIn(_secondsLeft) : l10n.resend,
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => context.pop(),
              child: Text(l10n.changeNumber),
            ),
          ],
        ),
      ),
    );
  }
}
