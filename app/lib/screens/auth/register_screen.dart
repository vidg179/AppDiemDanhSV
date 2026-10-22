import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/ui.dart';
import '../../widgets/auth_scaffold.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _studentCode = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _studentCode,
      _email,
      _phone,
      _username,
      _password,
      _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final challenge = await Api.post('/api/auth/register', {
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'fullName': _fullName.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        if (_studentCode.text.trim().isNotEmpty)
          'studentCode': _studentCode.text.trim(),
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
    const gap = SizedBox(height: 14);
    return AuthScaffold(
      title: 'Tạo tài khoản',
      subtitle:
          'Dành cho sinh viên. Tài khoản giảng viên do quản trị viên cấp.',
      showBack: true,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _fullName,
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => requiredField(v, 'họ và tên'),
            ),
            gap,
            TextFormField(
              controller: _studentCode,
              decoration: const InputDecoration(
                labelText: 'Mã sinh viên (không bắt buộc)',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            gap,
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) => emailPattern.hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Email không hợp lệ',
            ),
            gap,
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại (để nhận OTP SMS)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                return s.isEmpty || phonePattern.hasMatch(s)
                    ? null
                    : 'Số điện thoại 9-15 chữ số';
              },
            ),
            gap,
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: 'Tên đăng nhập',
                helperText: '3-30 ký tự: chữ không dấu, số, _ hoặc .',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => usernamePattern.hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Tên đăng nhập không hợp lệ',
            ),
            gap,
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: validatePassword,
            ),
            gap,
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nhập lại mật khẩu',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) =>
                  v == _password.text ? null : 'Mật khẩu nhập lại không khớp',
            ),
            const SizedBox(height: 24),
            BusyButton(label: 'Đăng ký', busy: _busy, onPressed: _register),
          ],
        ),
      ),
    );
  }
}
