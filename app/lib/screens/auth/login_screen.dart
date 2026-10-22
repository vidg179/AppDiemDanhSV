import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/ui.dart';
import '../../face/face_capture.dart';
import '../../widgets/auth_scaffold.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.capture = captureFace});

  final FaceCapture capture;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _faceLogin() async {
    final username = _username.text.trim();
    if (username.isEmpty) {
      showMessage(
        context,
        'Nhập tên đăng nhập hoặc email trước, rồi bấm Đăng nhập bằng khuôn mặt',
      );
      return;
    }
    final embedding = await widget.capture(
      context,
      'Nhìn thẳng vào camera để đăng nhập.',
    );
    if (embedding == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final auth = await Api.post('/api/auth/face-login', {
        'username': username,
        'embedding': embedding,
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

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final challenge = await Api.post('/api/auth/login', {
        'username': _username.text.trim(),
        'password': _password.text,
        'otpChannel': 'email',
      });
      if (!mounted) return;
      if (challenge['token'] != null) {
        // Tài khoản demo: server trả token luôn, không cần OTP.
        await Session.signIn(challenge);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => homeFor(Session.role)),
          (_) => false,
        );
        return;
      }
      Navigator.push(
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
      title: 'Điểm danh HUTECH',
      subtitle: 'Đăng nhập để điểm danh và theo dõi chuyên cần.',
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: 'Tên đăng nhập hoặc email',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                validator: (v) => requiredField(v, 'tên đăng nhập'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _hidePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _hidePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                  ),
                ),
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _login(),
                validator: (v) => requiredField(v, 'mật khẩu'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  ),
                  child: const Text('Quên mật khẩu?'),
                ),
              ),
              const SizedBox(height: 24),
              BusyButton(label: 'Đăng nhập', busy: _busy, onPressed: _login),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _busy ? null : _faceLogin,
                icon: const Icon(Icons.face_retouching_natural),
                label: const Text('Đăng nhập bằng khuôn mặt'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Chưa có tài khoản?'),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: const Text('Đăng ký'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
