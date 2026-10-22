import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/ui.dart';
import '../../widgets/common.dart';
import '../../widgets/home_shell.dart';
import '../common/class_students_screen.dart';
import 'class_form_screen.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  late Future<List<dynamic>> _classes = _load();

  Future<List<dynamic>> _load() async =>
      await Api.get('/api/classes') as List<dynamic>;

  Future<void> _reload() async {
    setState(() {
      _classes = _load();
    });
    await _classes;
  }

  Future<void> _openForm([Map<String, dynamic>? cls]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ClassFormScreen(classData: cls)),
    );
    if (saved == true) _reload();
  }

  Future<void> _openStudents(Map<String, dynamic> cls) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClassStudentsScreen(classData: cls)),
    );
    _reload();
  }

  Future<void> _delete(Map<String, dynamic> cls) async {
    final ok = await confirm(
      context,
      title: 'Xóa lớp ${cls['code']}?',
      message: 'Toàn bộ buổi học, dữ liệu điểm danh và đơn xin phép của lớp sẽ bị xóa vĩnh viễn.',
    );
    if (!ok) return;
    try {
      await Api.delete('/api/classes/${cls['id']}');
      if (mounted) {
        showMessage(context, 'Đã xóa lớp ${cls['code']}', error: false);
      }
      _reload();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm lớp'),
      ),
      body: AsyncListView(
        future: _classes,
        onRefresh: _reload,
        emptyIcon: Icons.school_outlined,
        emptyText: 'Chưa có lớp học nào. Bấm "Thêm lớp" để tạo lớp đầu tiên.',
        itemBuilder: (context, c) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ClassCard(
            data: c,
            onTap: () => _openStudents(c),
            trailing: PopupMenuButton<String>(
              tooltip: 'Thao tác',
              onSelected: (v) => switch (v) {
                'students' => _openStudents(c),
                'edit' => _openForm(c),
                _ => _delete(c),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'students',
                  child: ListTile(
                    leading: Icon(Icons.groups),
                    title: Text('Sinh viên'),
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Sửa'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Xóa'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
