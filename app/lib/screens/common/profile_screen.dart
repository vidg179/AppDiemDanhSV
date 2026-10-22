import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/ui.dart';
import '../../face/face_capture.dart';
import '../../widgets/common.dart';
import 'face_register_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.capture = captureFace});

  final FaceCapture capture;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _fullName = TextEditingController(
    text: Session.user?['fullName'] ?? '',
  );
  late final _phone = TextEditingController(text: Session.user?['phone'] ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      Session.user = Map<String, dynamic>.from(
        await Api.put('/api/users/me', {
          'fullName': _fullName.text.trim(),
          if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        }),
      );
      if (mounted) showMessage(context, 'Đã lưu hồ sơ', error: false);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      showMessage(context, 'Đổi mật khẩu thành công', error: false);
    }
  }

  Future<void> _registerFace() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FaceRegisterScreen(capture: widget.capture),
      ),
    );
    if (saved == true) setState(() {});
  }

  Future<void> _testFace() async {
    final e = await widget.capture(
      context,
      'Nhìn thẳng vào camera để thử nhận diện.',
    );
    if (e == null || !mounted) return;
    try {
      final r = await Api.post('/api/users/me/face/verify', {'embedding': e});
      if (!mounted) return;
      final percent = ((r['similarity'] as num) * 100).round();
      showMessage(
        context,
        r['match'] == true
            ? 'Khớp ($percent% giống)'
            : 'Không khớp ($percent% giống), nên đăng ký lại',
        error: r['match'] != true,
      );
    } on ApiException catch (err) {
      if (mounted) showMessage(context, err.message);
    }
  }

  Future<void> _removeFace() async {
    final ok = await confirm(
      context,
      title: 'Xóa khuôn mặt?',
      message: 'Bạn sẽ không đăng nhập hay điểm danh bằng khuôn mặt được nữa cho tới khi đăng ký lại.',
    );
    if (!ok) return;
    try {
      await Api.delete('/api/users/me/face');
      await Session.refresh();
      if (!mounted) return;
      setState(() {});
      showMessage(context, 'Đã xóa khuôn mặt', error: false);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Session.signOut();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final u = Session.user ?? {};
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(u['username'] ?? ''),
                  subtitle: const Text('Tên đăng nhập'),
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(u['email'] ?? ''),
                  subtitle: Text(
                    u['emailVerified'] == true
                        ? 'Email đã xác minh'
                        : 'Email chưa xác minh',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(roleText[u['role']] ?? ''),
                  subtitle: Text(
                    u['studentCode'] == null
                        ? 'Vai trò'
                        : 'Mã SV: ${u['studentCode']}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _fullName,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                  validator: (v) => requiredField(v, 'họ và tên'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    return s.isEmpty || phonePattern.hasMatch(s)
                        ? null
                        : 'Số điện thoại 9-15 chữ số';
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Lưu thay đổi'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.face_retouching_natural),
                  title: const Text('Khuôn mặt'),
                  subtitle: Text(
                    u['hasFace'] == true
                        ? 'Đã đăng ký: dùng để đăng nhập và điểm danh'
                        : 'Chưa đăng ký',
                  ),
                  trailing: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: _registerFace,
                    child: Text(
                      u['hasFace'] == true ? 'Đăng ký lại' : 'Đăng ký',
                    ),
                  ),
                ),
                if (u['hasFace'] == true)
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _testFace,
                        child: const Text('Thử nhận diện'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                        ),
                        onPressed: _removeFace,
                        child: const Text('Xóa khuôn mặt'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _changePassword,
            icon: const Icon(Icons.password),
            label: const Text('Đổi mật khẩu'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _signOut,
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.post('/api/users/me/change-password', {
        'currentPassword': _current.text,
        'newPassword': _next.text,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Đổi mật khẩu'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
            validator: validatePassword,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _busy ? null : _submit, child: const Text('Đổi')),
    ],
  );
}
