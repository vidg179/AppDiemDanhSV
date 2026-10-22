import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/time.dart';
import '../../core/ui.dart';
import '../../widgets/common.dart';
import 'attendance_map_screen.dart';
import 'attendance_widgets.dart';
import 'qr_screen.dart';
import 'session_form_screen.dart';

/// Một buổi học: tổng hợp, chiếu QR, bản đồ, danh sách điểm danh và sửa tay.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.session,
    required this.classData,
  });

  final Map<String, dynamic> session;
  final Map<String, dynamic> classData;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late Map<String, dynamic> _session = widget.session;
  late Future<List<dynamic>> _roster = _load();

  String get _id => _session['id'];

  Future<List<dynamic>> _load() async =>
      await Api.get('/api/sessions/$_id/attendance') as List<dynamic>;

  Future<void> _reload() async {
    setState(() {
      _roster = _load();
    });
    await _roster;
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SessionFormScreen(
          classId: widget.classData['id'],
          session: _session,
        ),
      ),
    );
    if (saved != true) return;
    final fresh = await Api.get('/api/sessions/$_id');
    setState(() => _session = Map<String, dynamic>.from(fresh));
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Xóa buổi "${_session['title']}"?',
      message: 'Dữ liệu điểm danh và đơn xin phép của buổi này cũng bị xóa.',
    );
    if (!ok) return;
    try {
      await Api.delete('/api/sessions/$_id');
      if (!mounted) return;
      showMessage(context, 'Đã xóa buổi học', error: false);
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  Future<void> _mark(Map<String, dynamic> row) async {
    if (await markAttendanceManually(context, _id, row)) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final hasLocation = s['latitude'] != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(s['title']),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Thao tác',
            onSelected: (v) => v == 'edit' ? _edit() : _delete(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Sửa buổi học'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Xóa buổi học'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<dynamic>>(
          future: _roster,
          builder: (context, snap) {
            final roster = snap.data ?? const [];
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    '${widget.classData['code']} · ${showRange(s['startTime'], s['endTime'])}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: AttendanceButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QrScreen(session: s),
                              ),
                            );
                            _reload();
                          },
                          icon: Icons.qr_code_2,
                          label: 'Chiếu mã QR',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                          onPressed: hasLocation && snap.hasData
                              ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AttendanceMapScreen(
                                      session: s,
                                      roster: roster,
                                    ),
                                  ),
                                )
                              : null,
                          icon: const Icon(Icons.map_outlined),
                          label: Text(
                            hasLocation ? 'Bản đồ' : 'Chưa đặt vị trí',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (snap.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snap.hasError)
                  InfoBox(
                    icon: Icons.cloud_off,
                    text: snap.error.toString(),
                    onRetry: _reload,
                  )
                else if (roster.isEmpty)
                  const InfoBox(
                    icon: Icons.groups_outlined,
                    text: 'Lớp chưa có sinh viên.',
                  )
                else ...[
                  AttendanceSummary(roster: roster),
                  for (final r in roster)
                    RosterTile(
                      row: Map<String, dynamic>.from(r),
                      onTap: () => _mark(r),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
