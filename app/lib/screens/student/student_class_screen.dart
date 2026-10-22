import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/time.dart';
import '../../widgets/common.dart';
import '../teacher/class_stats_view.dart';
import 'absence_form_screen.dart';

/// Lớp của sinh viên: tab Buổi học (trạng thái điểm danh của mình) và tab Chuyên cần.
class StudentClassScreen extends StatefulWidget {
  const StudentClassScreen({super.key, required this.classData});

  final Map<String, dynamic> classData;

  @override
  State<StudentClassScreen> createState() => _StudentClassScreenState();
}

class _StudentClassScreenState extends State<StudentClassScreen> {
  late Future<List<dynamic>> _rows = _load();

  String get _classId => widget.classData['id'];

  /// Ghép buổi học với bản ghi điểm danh của mình.
  Future<List<dynamic>> _load() async {
    final results = await Future.wait([
      Api.get('/api/classes/$_classId/sessions'),
      Api.get('/api/attendance/me?classId=$_classId'),
    ]);
    final records = {for (final a in results[1] as List) a['sessionId']: a};
    final now = DateTime.now();
    return [
      for (final s in (results[0] as List).reversed)
        {
          'session': s,
          'record': records[s['id']],
          'status':
              records[s['id']]?['status'] ??
              (fromApiTime(s['endTime']).isBefore(now) ? 'absent' : 'pending'),
        },
    ];
  }

  Future<void> _reload() async {
    setState(() {
      _rows = _load();
    });
    await _rows;
  }

  Future<void> _requestLeave(Map<String, dynamic> session) async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AbsenceFormScreen(session: session, classData: widget.classData),
      ),
    );
    if (sent == true) _reload();
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Buổi học'),
              Tab(text: 'Chuyên cần'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AsyncListView(
              future: _rows,
              onRefresh: _reload,
              emptyIcon: Icons.event_note_outlined,
              emptyText: 'Lớp chưa có buổi học nào.',
              itemBuilder: (context, row) {
                final s = Map<String, dynamic>.from(row['session']);
                final record = row['record'] as Map?;
                final status = row['status'] as String;
                final canLeave = status == 'pending' || status == 'absent';
                return ListTile(
                  title: Text(s['title']),
                  subtitle: Text(
                    [
                      showRange(s['startTime'], s['endTime']),
                      if (record?['checkInTime'] != null)
                        'quét lúc ${showTime(record!['checkInTime']).substring(0, 5)}',
                      if (record?['method'] == 'absence-request')
                        'theo đơn xin phép',
                    ].join(' · '),
                  ),
                  trailing: StatusChip(status),
                  onTap: canLeave ? () => _requestLeave(s) : null,
                );
              },
            ),
            ClassStatsView(classId: _classId),
          ],
        ),
      ),
    );
  }
}
