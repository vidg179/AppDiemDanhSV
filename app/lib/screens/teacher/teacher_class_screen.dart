import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/time.dart';
import '../../widgets/common.dart';
import '../common/class_students_screen.dart';
import 'absence_review_screen.dart';
import 'class_stats_view.dart';
import 'session_detail_screen.dart';
import 'session_form_screen.dart';

/// Lớp của giảng viên: tab Buổi học và tab Thống kê.
class TeacherClassScreen extends StatefulWidget {
  const TeacherClassScreen({super.key, required this.classData});

  final Map<String, dynamic> classData;

  @override
  State<TeacherClassScreen> createState() => _TeacherClassScreenState();
}

class _TeacherClassScreenState extends State<TeacherClassScreen> {
  late Future<List<dynamic>> _sessions = _load();

  String get _classId => widget.classData['id'];

  Future<List<dynamic>> _load() async {
    final list =
        await Api.get('/api/classes/$_classId/sessions') as List<dynamic>;
    return list.reversed.toList(); // buổi mới nhất lên đầu
  }

  Future<void> _reload() async {
    setState(() {
      _sessions = _load();
    });
    await _sessions;
  }

  Future<void> _createSession() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SessionFormScreen(classId: _classId)),
    );
    if (saved == true) _reload();
  }

  Future<void> _openSession(Map<String, dynamic> s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SessionDetailScreen(session: s, classData: widget.classData),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cls = widget.classData;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cls['code']),
              Text(cls['name'], style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Sinh viên của lớp',
              icon: const Icon(Icons.groups_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClassStudentsScreen(classData: cls),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Đơn xin phép của lớp',
              icon: const Icon(Icons.mark_email_unread_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AbsenceReviewScreen(classId: cls['id']),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Buổi học'),
              Tab(text: 'Thống kê'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createSession,
          icon: const Icon(Icons.add),
          label: const Text('Tạo buổi học'),
        ),
        body: TabBarView(
          children: [
            AsyncListView(
              future: _sessions,
              onRefresh: _reload,
              emptyIcon: Icons.event_note_outlined,
              emptyText: 'Lớp chưa có buổi học. Bấm "Tạo buổi học" để bắt đầu điểm danh.',
              itemBuilder: (context, s) =>
                  _SessionTile(session: s, onTap: () => _openSession(s)),
            ),
            ClassStatsView(classId: _classId),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onTap});

  final Map<String, dynamic> session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = fromApiTime(session['startTime']);
    final end = fromApiTime(session['endTime']);
    final now = DateTime.now();
    final (label, status) = now.isBefore(start)
        ? ('Sắp diễn ra', 'excused')
        : now.isAfter(end)
        ? ('Đã kết thúc', 'pending')
        : ('Đang diễn ra', 'present');
    final flags = [
      if (session['latitude'] != null) 'GPS',
      if (session['requireFace'] == true) 'Khuôn mặt',
    ];
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
        leading: DateBlock(start),
        title: Text(session['title']),
        subtitle: Text(
          [
            showHours(session['startTime'], session['endTime']),
            ...flags,
          ].join(' · '),
        ),
        trailing: StatusChip(status, labels: {status: label}),
      ),
    );
  }
}
