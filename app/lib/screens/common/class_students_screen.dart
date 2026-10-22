import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/ui.dart';
import '../../widgets/common.dart';

/// Danh sách sinh viên của lớp: thêm nhiều sinh viên, xóa khỏi lớp. Dùng cho admin và giảng viên.
class ClassStudentsScreen extends StatefulWidget {
  const ClassStudentsScreen({super.key, required this.classData});

  final Map<String, dynamic> classData;

  @override
  State<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends State<ClassStudentsScreen> {
  late Future<List<dynamic>> _students = _load();

  String get _classId => widget.classData['id'];

  Future<List<dynamic>> _load() async =>
      await Api.get('/api/classes/$_classId/students') as List<dynamic>;

  Future<void> _reload() async {
    setState(() {
      _students = _load();
    });
    await _students;
  }

  Future<void> _add() async {
    final current = await _students.catchError((_) => <dynamic>[]);
    if (!mounted) return;
    final ids = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => StudentPickerScreen(
          excludeIds: {for (final s in current) s['id'] as String},
        ),
      ),
    );
    if (ids == null || ids.isEmpty) return;
    try {
      await Api.post('/api/classes/$_classId/students', {'studentIds': ids});
      if (mounted) {
        showMessage(
          context,
          'Đã thêm ${ids.length} sinh viên vào lớp',
          error: false,
        );
      }
      _reload();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  Future<void> _remove(Map<String, dynamic> student) async {
    final ok = await confirm(
      context,
      title: 'Xóa ${student['fullName']} khỏi lớp?',
      message: 'Sinh viên sẽ không thấy lớp này và không điểm danh được nữa.',
      action: 'Xóa khỏi lớp',
    );
    if (!ok) return;
    try {
      await Api.delete('/api/classes/$_classId/students/${student['id']}');
      if (mounted) {
        showMessage(
          context,
          'Đã xóa ${student['fullName']} khỏi lớp',
          error: false,
        );
      }
      _reload();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sinh viên lớp ${widget.classData['code']}'),
            Text(
              widget.classData['name'],
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.group_add),
        label: const Text('Thêm sinh viên'),
      ),
      body: AsyncListView(
        future: _students,
        onRefresh: _reload,
        emptyIcon: Icons.groups_outlined,
        emptyText: 'Lớp chưa có sinh viên. Bấm "Thêm sinh viên" để thêm.',
        itemBuilder: (context, s) => ListTile(
          leading: CircleAvatar(child: Text(initials(s['fullName']))),
          title: Text(s['fullName']),
          subtitle: Text(
            [
              if (s['studentCode'] != null) s['studentCode'],
              s['email'],
            ].join(' · '),
          ),
          trailing: IconButton(
            tooltip: 'Xóa khỏi lớp',
            icon: const Icon(Icons.person_remove_outlined),
            onPressed: () => _remove(s),
          ),
        ),
      ),
    );
  }
}

/// Chọn nhiều sinh viên chưa có trong lớp. Trả về danh sách id.
class StudentPickerScreen extends StatefulWidget {
  const StudentPickerScreen({super.key, required this.excludeIds});

  final Set<String> excludeIds;

  @override
  State<StudentPickerScreen> createState() => _StudentPickerScreenState();
}

class _StudentPickerScreenState extends State<StudentPickerScreen> {
  late final Future<List<dynamic>> _students = _load();
  final _selected = <String>{};
  String _query = '';

  Future<List<dynamic>> _load() async {
    final all = await Api.get('/api/users?role=student') as List<dynamic>;
    return all.where((s) => !widget.excludeIds.contains(s['id'])).toList();
  }

  bool _matches(Map s) {
    final q = _query.toLowerCase();
    return q.isEmpty ||
        [
          s['fullName'],
          s['username'],
          s['studentCode'] ?? '',
          s['email'],
        ].any((v) => v.toString().toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn sinh viên')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, _selected.toList()),
            child: Text(
              _selected.isEmpty
                  ? 'Chọn sinh viên để thêm'
                  : 'Thêm ${_selected.length} sinh viên',
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                hintText: 'Tìm sinh viên',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _students,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return InfoBox(
                    icon: Icons.cloud_off,
                    text: snap.error.toString(),
                  );
                }
                final list = snap.data!.where((s) => _matches(s)).toList();
                if (list.isEmpty) {
                  return const InfoBox(
                    icon: Icons.person_search,
                    text: 'Không còn sinh viên nào để thêm vào lớp.',
                  );
                }
                return ListView(
                  children: [
                    for (final s in list)
                      CheckboxListTile(
                        value: _selected.contains(s['id']),
                        onChanged: (v) => setState(
                          () => v == true
                              ? _selected.add(s['id'])
                              : _selected.remove(s['id']),
                        ),
                        title: Text(s['fullName']),
                        subtitle: Text(
                          [
                            if (s['studentCode'] != null) s['studentCode'],
                            '@${s['username']}',
                          ].join(' · '),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
