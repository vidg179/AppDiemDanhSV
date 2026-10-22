import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/ui.dart';
import '../../face/face_capture.dart';

/// Đăng ký khuôn mặt: chụp 3 góc rồi xác nhận mật khẩu. Trả về true khi đã lưu.
class FaceRegisterScreen extends StatefulWidget {
  const FaceRegisterScreen({super.key, this.capture = captureFace});

  final FaceCapture capture;

  @override
  State<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends State<FaceRegisterScreen> {
  static const _steps = [
    ('Nhìn thẳng', 'Nhìn thẳng vào camera.'),
    ('Hơi quay trái', 'Quay mặt sang trái một chút.'),
    ('Hơi quay phải', 'Quay mặt sang phải một chút.'),
  ];

  final _embeddings = <List<double>>[];
  final _password = TextEditingController();
  bool _busy = false;

  bool get _needsPassword => Session.user?['provider'] != 'google';

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _captureNext() async {
    final (_, hint) = _steps[_embeddings.length];
    final e = await widget.capture(context, hint);
    if (e != null) setState(() => _embeddings.add(e));
  }

  Future<void> _save() async {
    if (_needsPassword && _password.text.isEmpty) {
      showMessage(context, 'Nhập mật khẩu hiện tại để xác nhận');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.post('/api/users/me/face', {
        'embeddings': _embeddings,
        if (_needsPassword) 'password': _password.text,
      });
      await Session.refresh();
      if (!mounted) return;
      showMessage(context, 'Đã đăng ký khuôn mặt', error: false);
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showMessage(context, e.message);
      if (e.message.contains('không giống')) setState(_embeddings.clear);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = _embeddings.length == _steps.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký khuôn mặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Chụp 3 ảnh khuôn mặt ở 3 góc. App chỉ gửi dãy số đặc trưng lên máy chủ, không gửi ảnh.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          for (final (i, (title, _)) in _steps.indexed)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: i < _embeddings.length
                      ? brandColor
                      : scheme.surfaceContainerHighest,
                  foregroundColor: i < _embeddings.length
                      ? Colors.white
                      : scheme.onSurfaceVariant,
                  child: Icon(
                    i < _embeddings.length ? Icons.check : Icons.face_outlined,
                  ),
                ),
                title: Text('Ảnh ${i + 1}: $title'),
                subtitle: Text(
                  i < _embeddings.length ? 'Đã chụp' : 'Chưa chụp',
                ),
                trailing: i == _embeddings.length
                    ? FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                        onPressed: _captureNext,
                        child: const Text('Chụp'),
                      )
                    : null,
              ),
            ),
          if (_embeddings.isNotEmpty && !done)
            TextButton(
              onPressed: () => setState(_embeddings.clear),
              child: const Text('Chụp lại từ đầu'),
            ),
          if (done) ...[
            const SizedBox(height: 16),
            if (_needsPassword)
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại (để xác nhận)',
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Lưu khuôn mặt'),
            ),
          ],
        ],
      ),
    );
  }
}
