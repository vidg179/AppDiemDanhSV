import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/ui.dart';
import '../../widgets/auth_scaffold.dart';

/// Nhập OTP. Dùng chung cho đăng nhập, xác minh email khi đăng ký và quên mật khẩu.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.challenge});

  final Map<String, dynamic> challenge;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _resendSeconds = 30;

  final _form = GlobalKey<FormState>();
  late Map<String, dynamic> _challenge = widget.challenge;
  late final _code = TextEditingController(
    text: widget.challenge['devCode'] ?? '',
  );
  final _newPassword = TextEditingController();
  bool _busy = false;
  int _wait = _resendSeconds;
  Timer? _timer;

  bool get _isReset => _challenge['purpose'] == 'reset-password';

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _wait = _resendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_wait <= 1) t.cancel();
      setState(() => _wait--);
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final auth = _isReset
          ? await Api.post('/api/auth/reset-password', {
              'ticket': _challenge['ticket'],
              'code': _code.text.trim(),
              'newPassword': _newPassword.text,
            })
          : await Api.post('/api/auth/verify-otp', {
              'ticket': _challenge['ticket'],
              'code': _code.text.trim(),
            });
      await Session.signIn(auth);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => homeFor(Session.role)),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      final c = await Api.post('/api/auth/resend-otp', {
        'ticket': _challenge['ticket'],
      });
      setState(() {
        _challenge = c;
        _code.text = c['devCode'] ?? '';
      });
      _startCountdown();
      if (mounted) showMessage(context, 'Đã gửi lại mã OTP', error: false);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final via = _challenge['channel'] == 'sms' ? 'tin nhắn SMS' : 'email';
    final title = switch (_challenge['purpose']) {
      'verify-email' => 'Xác minh email',
      'reset-password' => 'Đặt lại mật khẩu',
      _ => 'Nhập mã OTP',
    };

    return AuthScaffold(
      title: title,
      subtitle:
          'Mã 6 số đã được gửi qua $via tới ${_challenge['destination']}. Mã có hiệu lực 5 phút.',
      showBack: true,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_challenge['devCode'] != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Chế độ demo: mã OTP đã được điền sẵn.',
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
              ),
            TextFormField(
              controller: _code,
              autofocus: _challenge['devCode'] == null,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 12,
                fontWeight: FontWeight.w600,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                hintText: '••••••',
              ),
              validator: (v) =>
                  (v == null || v.length != 6) ? 'Mã OTP gồm 6 chữ số' : null,
              onFieldSubmitted: (_) => _isReset ? null : _submit(),
            ),
            if (_isReset) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _newPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mới',
                  prefixIcon: Icon(Icons.lock_reset),
                ),
                validator: validatePassword,
              ),
            ],
            const SizedBox(height: 24),
            BusyButton(
              label: _isReset ? 'Đặt mật khẩu mới' : 'Xác nhận',
              busy: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _wait > 0 ? null : _resend,
              child: Text(
                _wait > 0 ? 'Gửi lại mã sau $_wait giây' : 'Gửi lại mã',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
