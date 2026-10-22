import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/ui.dart';

/// Thêm (classData == null) hoặc sửa lớp học. Trả về true khi đã lưu.
class ClassFormScreen extends StatefulWidget {
  const ClassFormScreen({super.key, this.classData});

  final Map<String, dynamic>? classData;

  @override
  State<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends State<ClassFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(
    text: widget.classData?['code'] ?? '',
  );
  late final _name = TextEditingController(
    text: widget.classData?['name'] ?? '',
  );
  late final _subject = TextEditingController(
    text: widget.classData?['subject'] ?? '',
  );
  late final _room = TextEditingController(
    text: widget.classData?['room'] ?? '',
  );
  late String? _teacherId = widget.classData?['teacherId'];
  late final Future<List<dynamic>> _teachers = _loadTeachers();
  bool _busy = false;

  bool get _isEdit => widget.classData != null;

  Future<List<dynamic>> _loadTeachers() async =>
      await Api.get('/api/users?role=teacher') as List<dynamic>;

  @override
  void dispose() {
    for (final c in [_code, _name, _subject, _room]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final body = {
      'code': _code.text.trim(),
      'name': _name.text.trim(),
      if (_subject.text.trim().isNotEmpty) 'subject': _subject.text.trim(),
      if (_room.text.trim().isNotEmpty) 'room': _room.text.trim(),
      if (_teacherId != null) 'teacherId': _teacherId,
    };
    try {
      if (_isEdit) {
        await Api.put('/api/classes/${widget.classData!['id']}', body);
      } else {
        await Api.post('/api/classes', body);
      }
      if (!mounted) return;
      showMessage(
        context,
        _isEdit ? 'Đã lưu lớp ${body['code']}' : 'Đã tạo lớp ${body['code']}',
        error: false,
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa lớp học' : 'Thêm lớp học')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Mã lớp',
                hintText: 'VD: LTDD01',
              ),
              validator: (v) => requiredField(v, 'mã lớp'),
            ),
            gap,
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Tên lớp',
                hintText: 'VD: Lập trình thiết bị di động',
              ),
              validator: (v) => requiredField(v, 'tên lớp'),
            ),
            gap,
            TextFormField(
              controller: _subject,
              decoration: const InputDecoration(
                labelText: 'Môn học (không bắt buộc)',
              ),
            ),
            gap,
            TextFormField(
              controller: _room,
              decoration: const InputDecoration(
                labelText: 'Phòng học (không bắt buộc)',
                hintText: 'VD: A101',
              ),
            ),
            gap,
            FutureBuilder<List<dynamic>>(
              future: _teachers,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snap.hasError) {
                  return Text(
                    'Không tải được danh sách giảng viên: ${snap.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
                final teachers = snap.data!;
                final current = teachers.any((t) => t['id'] == _teacherId)
                    ? _teacherId
                    : null;
                return DropdownButtonFormField<String?>(
                  initialValue: current,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Giảng viên phụ trách',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Chưa phân công'),
                    ),
                    for (final t in teachers)
                      DropdownMenuItem<String?>(
                        value: t['id'],
                        child: Text(
                          '${t['fullName']} (@${t['username']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => _teacherId = v,
                );
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_isEdit ? 'Lưu thay đổi' : 'Tạo lớp'),
            ),
          ],
        ),
      ),
    );
  }
}
