import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api.dart';
import '../../core/time.dart';
import '../../widgets/common.dart';
import 'attendance_widgets.dart';

/// Điểm danh bằng QR: chiếu mã 60 giây. Hết giờ thì QR tắt và hiện danh sách sinh viên để
/// giảng viên tạo mã mới cho người chưa kịp quét, hoặc điểm danh tay cho người bị lỗi.
class QrScreen extends StatefulWidget {
  const QrScreen({super.key, required this.session});

  final Map<String, dynamic> session;

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  static const _validMinutes = 1;
  static const _pollEvery = 4; // giây

  Map<String, dynamic>? _qr; // null khi QR đã tắt
  bool _loading = true;
  String? _error;
  List<dynamic> _roster = [];
  String? _rosterError;
  Timer? _timer;
  int _ticks = 0;

  String get _sessionId => widget.session['id'];

  @override
  void initState() {
    super.initState();
    _newQr();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final qr = _qr;
    if (qr != null && !fromApiTime(qr['expiresAt']).isAfter(DateTime.now())) {
      setState(() => _qr = null); // hết 60 giây: tắt QR, hiện danh sách
      _loadRoster();
      return;
    }
    _ticks++;
    if (qr != null && _ticks % _pollEvery == 0) _loadRoster();
    if (qr != null) setState(() {});
  }

  Future<void> _newQr() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final qr = await Api.post('/api/sessions/$_sessionId/qr', {
        'validMinutes': _validMinutes,
      });
      if (!mounted) return;
      setState(() => _qr = Map<String, dynamic>.from(qr));
      _loadRoster();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRoster() async {
    try {
      final list = await Api.get(
        '/api/sessions/$_sessionId/attendance',
      ) as List<dynamic>;
      if (mounted) {
        setState(() {
          _roster = list;
          _rosterError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _rosterError = e.toString());
    }
  }

  Future<void> _mark(Map<String, dynamic> row) async {
    if (await markAttendanceManually(context, _sessionId, row)) _loadRoster();
  }

  bool _attended(dynamic r) =>
      r['status'] == 'present' ||
      r['status'] == 'late' ||
      r['status'] == 'excused';

  /// Sinh viên chưa điểm danh lên đầu để giảng viên xử lý trước.
  List<Map<String, dynamic>> get _sorted {
    final rows = [for (final r in _roster) Map<String, dynamic>.from(r)];
    rows.sort((a, b) {
      final byAttended = (_attended(a) ? 1 : 0).compareTo(_attended(b) ? 1 : 0);
      return byAttended != 0
          ? byAttended
          : (a['fullName'] as String).compareTo(b['fullName']);
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final active = _qr != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Điểm danh bằng QR')),
      body: active ? _activeView(context) : _expiredView(context),
    );
  }

  Widget _activeView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final qr = _qr!;
    final left = fromApiTime(qr['expiresAt']).difference(DateTime.now());
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    final attended = _roster
        .where((r) => r['status'] == 'present' || r['status'] == 'late')
        .length;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              widget.session['title'],
              style: text.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Sinh viên mở app, chọn "Quét QR điểm danh"',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: qr['qrToken'],
                size: 280,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              'Mã: ${qr['qrToken']}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '$mm:$ss',
              style: text.displaySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _roster.isEmpty
                  ? 'Đang chờ sinh viên quét...'
                  : 'Đã điểm danh $attended/${_roster.length}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _qr = null);
                _loadRoster();
              },
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Dừng mã, xem danh sách'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expiredView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final rows = _sorted;
    final missing = rows.where((r) => !_attended(r)).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _loading ? 'Đang tạo mã mới...' : 'Mã QR đã tắt',
                style: text.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _roster.isEmpty
                    ? 'Đang tải danh sách...'
                    : missing == 0
                    ? 'Tất cả sinh viên đã được điểm danh.'
                    : 'Còn $missing sinh viên chưa điểm danh. Tạo mã mới hoặc bấm vào tên để điểm danh tay.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _newQr,
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Tạo mã mới (60 giây)'),
              ),
            ],
          ),
        ),
        if (_roster.isNotEmpty) AttendanceSummary(roster: _roster),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRoster,
            child: _rosterError != null && _roster.isEmpty
                ? ListView(
                    children: [
                      InfoBox(
                        icon: Icons.cloud_off,
                        text: _rosterError!,
                        onRetry: _loadRoster,
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (final r in rows)
                        RosterTile(row: r, onTap: () => _mark(r)),
                    ],
                  ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Xong, về buổi học'),
            ),
          ),
        ),
      ],
    );
  }
}
