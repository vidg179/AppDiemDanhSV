import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/time.dart';
import '../../core/ui.dart';
import '../../widgets/common.dart';

/// Giảng viên điểm danh tay cho một sinh viên: chọn trạng thái + ghi chú, lưu lên server ngay.
/// Trả về true nếu đã lưu.
Future<bool> markAttendanceManually(
  BuildContext context,
  String sessionId,
  Map<String, dynamic> row,
) async {
  final result = await showModalBottomSheet<(String, String)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => MarkSheet(row: row),
  );
  if (result == null || !context.mounted) return false;
  final (status, note) = result;
  try {
    await Api.post('/api/attendance', {
      'sessionId': sessionId,
      'studentId': row['studentId'],
      'status': status,
      if (note.isNotEmpty) 'note': note,
    });
    if (context.mounted) {
      showMessage(
        context,
        'Đã lưu: ${row['fullName']} - ${statusText[status]}',
        error: false,
      );
    }
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showMessage(context, e.message);
    return false;
  }
}

class AttendanceSummary extends StatelessWidget {
  const AttendanceSummary({super.key, required this.roster});

  final List<dynamic> roster;

  @override
  Widget build(BuildContext context) {
    int count(String s) => roster.where((r) => r['status'] == s).length;
    final attended = count('present') + count('late');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              'Có mặt $attended/${roster.length}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          for (final s in ['present', 'late', 'excused', 'absent', 'pending'])
            if (count(s) > 0)
              StatusChip(s, labels: {s: '${statusText[s]} ${count(s)}'}),
        ],
      ),
    );
  }
}

class RosterTile extends StatelessWidget {
  const RosterTile({super.key, required this.row, required this.onTap});

  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (row['studentCode'] != null) row['studentCode'],
      if (row['checkInTime'] != null)
        'lúc ${showTime(row['checkInTime']).substring(0, 5)}',
      if (row['method'] == 'manual') 'điểm danh tay',
      if (row['method'] == 'absence-request') 'theo đơn xin phép',
      if (row['distanceMeters'] != null)
        'cách lớp ${(row['distanceMeters'] as num).round()} m',
      if (row['faceVerified'] == true) 'đã xác thực mặt',
    ].join(' · ');
    return ListTile(
      onTap: onTap,
      leading: Avatar(row['fullName']),
      title: Text(row['fullName']),
      subtitle: Text(
        row['note'] == null ? details : '$details\nGhi chú: ${row['note']}',
      ),
      trailing: StatusChip(row['status']),
    );
  }
}

/// Chọn trạng thái điểm danh tay cho một sinh viên. Trả về (status, note).
class MarkSheet extends StatefulWidget {
  const MarkSheet({super.key, required this.row});

  final Map<String, dynamic> row;

  @override
  State<MarkSheet> createState() => MarkSheetState();
}

class MarkSheetState extends State<MarkSheet> {
  late String _status = widget.row['status'] == 'pending'
      ? 'present'
      : widget.row['status'];
  late final _note = TextEditingController(text: widget.row['note'] ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Điểm danh ${widget.row['fullName']}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in ['present', 'late', 'excused', 'absent'])
                ChoiceChip(
                  label: Text(statusText[s]!),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Ghi chú (không bắt buộc)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, (_status, _note.text.trim())),
            child: const Text('Lưu điểm danh'),
          ),
        ],
      ),
    );
  }
}
