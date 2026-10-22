import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/ui.dart';
import '../../widgets/common.dart';

/// Thêm (user == null) hoặc sửa người dùng. Trả về true khi đã lưu.
class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, this.user});

  final Map<String, dynamic>? user;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _username = TextEditingController(
    text: widget.user?['username'] ?? '',
  );
  late final _fullName = TextEditingController(
    text: widget.user?['fullName'] ?? '',
  );
  late final _email = TextEditingController(text: widget.user?['email'] ?? '');
  late final _phone = TextEditingController(text: widget.user?['phone'] ?? '');
  late final _studentCode = TextEditingController(
    text: widget.user?['studentCode'] ?? '',
  );
  final _password = TextEditingController();
  late String _role = widget.user?['role'] ?? 'student';
  late bool _hasFace = widget.user?['hasFace'] == true;
  bool _busy = false;

  bool get _isEdit => widget.user != null;

  @override
  void dispose() {
    for (final c in [
      _username,
      _fullName,
      _email,
      _phone,
      _studentCode,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final phone = _phone.text.trim();
    final code = _studentCode.text.trim();
    final body = <String, dynamic>{
      'email': _email.text.trim(),
      'fullName': _fullName.text.trim(),
      'role': _role,
      if (phone.isNotEmpty) 'phone': phone,
      if (_role == 'student' && code.isNotEmpty) 'studentCode': code,
    };
    try {
      if (_isEdit) {
        if (_password.text.isNotEmpty) body['newPassword'] = _password.text;
        await Api.put('/api/users/${widget.user!['id']}', body);
      } else {
        body['username'] = _username.text.trim();
        body['password'] = _password.text;
        await Api.post('/api/users', body);
      }
      if (!mounted) return;
      showMessage(
        context,
        _isEdit ? 'Đã lưu thay đổi' : 'Đã thêm ${body['fullName']}',
        error: false,
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFace() async {
    final ok = await confirm(
      context,
      title: 'Xóa khuôn mặt đã đăng ký?',
      message: 'Người dùng sẽ phải đăng ký lại khuôn mặt mới đăng nhập hoặc điểm danh bằng khuôn mặt được.',
    );
    if (!ok) return;
    try {
      await Api.delete('/api/users/${widget.user!['id']}/face');
      setState(() => _hasFace = false);
      if (mounted) showMessage(context, 'Đã xóa khuôn mặt', error: false);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa người dùng' : 'Thêm người dùng'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _username,
              enabled: !_isEdit,
              decoration: InputDecoration(
                labelText: 'Tên đăng nhập',
                helperText: _isEdit
                    ? 'Không đổi được tên đăng nhập'
                    : '3-30 ký tự: chữ không dấu, số, _ hoặc .',
              ),
              validator: (v) =>
                  _isEdit || usernamePattern.hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Tên đăng nhập không hợp lệ',
            ),
            gap,
            TextFormField(
              controller: _fullName,
              decoration: const InputDecoration(labelText: 'Họ và tên'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => requiredField(v, 'họ và tên'),
            ),
            gap,
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => emailPattern.hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Email không hợp lệ',
            ),
            gap,
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Vai trò'),
              items: [
                for (final r in ['student', 'teacher', 'admin'])
                  DropdownMenuItem(value: r, child: Text(roleText[r]!)),
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),
            if (_role == 'student') ...[
              gap,
              TextFormField(
                controller: _studentCode,
                decoration: const InputDecoration(
                  labelText: 'Mã sinh viên (không bắt buộc)',
                ),
              ),
            ],
            gap,
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại (không bắt buộc)',
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
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _isEdit
                    ? 'Mật khẩu mới (để trống nếu không đổi)'
                    : 'Mật khẩu',
              ),
              validator: (v) =>
                  _isEdit && (v ?? '').isEmpty ? null : validatePassword(v),
            ),
            if (_isEdit && _hasFace) ...[
              gap,
              OutlinedButton.icon(
                onPressed: _removeFace,
                icon: const Icon(Icons.face_retouching_off),
                label: const Text('Xóa khuôn mặt đã đăng ký'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_isEdit ? 'Lưu thay đổi' : 'Thêm người dùng'),
            ),
          ],
        ),
      ),
    );
  }
}
