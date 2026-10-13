import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/format.dart';
import '../services/shop_api.dart';
import '../widgets/common.dart';

Widget _authHeader(String title, String subtitle) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: AppColors.navy, fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(
                color: AppColors.slate, fontSize: 14, height: 1.35)),
        const SizedBox(height: 24),
      ],
    );

/// Enter the 6-digit code emailed after registration. Pops `true` on success.
class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({
    super.key,
    required this.email,
    this.deliveryMessage,
  });
  final String email;
  final String? deliveryMessage;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  int _cooldown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 30);
    _tick();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
      }
      if (mounted) setState(() => _cooldown--);
    });
  }

  Future<void> _verify() async {
    if (_code.text.trim().length < 4) {
      showMessage(context, 'Enter the code from your email.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final msg = await ShopApi.verify(widget.email, _code.text.trim());
      if (!mounted) return;
      showMessage(context, msg);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, e.toString(), error: true);
      }
    }
  }

  Future<void> _resend() async {
    try {
      final msg = await ShopApi.resendCode(widget.email);
      if (!mounted) return;
      showMessage(context, msg);
      _startCooldown();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _authHeader(
            'Verify your email',
            (widget.deliveryMessage?.toLowerCase().contains('console') ?? false)
                ? 'Check the backend console for the 6-digit code for\n${widget.email}'
                : 'We sent a 6-digit code to\n${widget.email}',
          ),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(fontSize: 26, letterSpacing: 8),
            decoration: const InputDecoration(hintText: '------', counterText: ''),
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Verify', loading: _busy, onPressed: _verify),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _cooldown > 0 ? null : _resend,
              child: Text(_cooldown > 0
                  ? 'Resend code in ${_cooldown}s'
                  : 'Resend code'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two steps: ask for the email, then enter code + new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (validateEmailField(_email.text) != null) {
      showMessage(context, 'Enter a valid email address.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final msg = await ShopApi.forgotPassword(_email.text.trim());
      if (!mounted) return;
      showMessage(context, msg);
      setState(() {
        _codeSent = true;
        _busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, e.toString(), error: true);
      }
    }
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final msg = await ShopApi.resetPassword(
        email: _email.text.trim(),
        code: _code.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      showMessage(context, msg);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _authHeader(
                'Forgot password?',
                _codeSent
                    ? 'Enter the code we emailed you and choose a new password.'
                    : 'Enter your email and we will send you a reset code.'),
            TextFormField(
              controller: _email,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  fieldDecoration('Email Address', icon: Icons.mail_outline_rounded),
              validator: validateEmailField,
            ),
            if (!_codeSent) ...[
              const SizedBox(height: 20),
              PrimaryButton(label: 'Send Code', loading: _busy, onPressed: _sendCode),
            ] else ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration('Reset code', icon: Icons.pin_outlined),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter the code.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration:
                    fieldDecoration('New password', icon: Icons.lock_outline_rounded),
                validator: validateStrongPassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: fieldDecoration('Confirm new password',
                    icon: Icons.lock_outline_rounded),
                validator: (v) =>
                    v != _password.text ? 'Passwords do not match.' : null,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                  label: 'Reset Password', loading: _busy, onPressed: _reset),
              Center(
                child: TextButton(
                    onPressed: _busy ? null : _sendCode,
                    child: const Text('Send a new code')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
