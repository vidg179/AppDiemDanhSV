import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/ui.dart';
import '../../widgets/auth_scaffold.dart';
import 'otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  String _channel = 'email';
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final challenge = await Api.post('/api/auth/forgot-password', {
        'username': _username.text.trim(),
        'otpChannel': _channel,
      });
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OtpScreen(challenge: challenge)),
      );
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Quên mật khẩu',
      subtitle: 'Nhập tên đăng nhập hoặc email, chúng tôi gửi mã OTP để bạn đặt mật khẩu mới.',
      showBack: true,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: 'Tên đăng nhập hoặc email',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => requiredField(v, 'tên đăng nhập hoặc email'),
              onFieldSubmitted: (_) => _send(),
            ),
            const SizedBox(height: 18),
            OtpChannelPicker(
              value: _channel,
              onChanged: (v) => setState(() => _channel = v),
            ),
            const SizedBox(height: 24),
            BusyButton(label: 'Gửi mã OTP', busy: _busy, onPressed: _send),
          ],
        ),
      ),
    );
  }
}
