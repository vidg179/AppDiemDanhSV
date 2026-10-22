import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/time.dart';
import '../../widgets/common.dart';
import '../teacher/absence_review_screen.dart';

/// Các đơn xin phép sinh viên đã gửi.
class MyAbsenceScreen extends StatefulWidget {
  const MyAbsenceScreen({super.key});

  @override
  State<MyAbsenceScreen> createState() => _MyAbsenceScreenState();
}

class _MyAbsenceScreenState extends State<MyAbsenceScreen> {
  late Future<List<dynamic>> _requests = _load();

  Future<List<dynamic>> _load() async =>
      await Api.get('/api/absence-requests') as List<dynamic>;

  Future<void> _reload() async {
    setState(() {
      _requests = _load();
    });
    await _requests;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn xin phép của tôi')),
      body: AsyncListView(
        future: _requests,
        onRefresh: _reload,
        emptyIcon: Icons.inbox_outlined,
        emptyText: 'Bạn chưa gửi đơn nào. Vào lớp, bấm vào buổi học muốn nghỉ để xin phép.',
        itemBuilder: (context, r) => ListTile(
          title: Text(r['sessionTitle']),
          subtitle: Text(
            '${r['className']} · ${showDate(r['sessionStart'])}\n${r['reason']}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
          trailing: StatusChip(r['status'], labels: absenceStatusText),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AbsenceDetailScreen(request: r, canReview: false),
              ),
            );
            _reload();
          },
        ),
      ),
    );
  }
}
