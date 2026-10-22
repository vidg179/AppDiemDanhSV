import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/time.dart';
import '../../core/ui.dart';
import '../../widgets/common.dart';

/// Danh sách đơn xin phép của các lớp giảng viên dạy (lọc theo lớp nếu có classId).
class AbsenceReviewScreen extends StatefulWidget {
  const AbsenceReviewScreen({super.key, this.classId});

  final String? classId;

  @override
  State<AbsenceReviewScreen> createState() => _AbsenceReviewScreenState();
}

class _AbsenceReviewScreenState extends State<AbsenceReviewScreen> {
  static const _filters = <(String?, String)>[
    ('pending', 'Chờ duyệt'),
    ('approved', 'Đã duyệt'),
    ('rejected', 'Từ chối'),
    (null, 'Tất cả'),
  ];

  String? _status = 'pending';
  late Future<List<dynamic>> _requests = _load();

  Future<List<dynamic>> _load() async {
    final query = {'status': ?_status, 'classId': ?widget.classId};
    final qs = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    return await Api.get('/api/absence-requests$qs') as List<dynamic>;
  }

  Future<void> _reload() async {
    setState(() {
      _requests = _load();
    });
    await _requests;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn xin phép')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final (value, label) in _filters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _status == value,
                      onSelected: (_) {
                        _status = value;
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncListView(
              future: _requests,
              onRefresh: _reload,
              emptyIcon: Icons.inbox_outlined,
              emptyText: _status == 'pending'
                  ? 'Không có đơn nào chờ duyệt.'
                  : 'Không có đơn nào.',
              itemBuilder: (context, r) => ListTile(
                leading: Avatar(r['studentName']),
                title: Text(r['studentName']),
                subtitle: Text(
                  '${r['classCode'] ?? r['className']} · ${r['sessionTitle']} · ${showDate(r['sessionStart'])}\n'
                  '${absenceCategoryText[r['category']] ?? r['category']}: ${r['reason']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: StatusChip(r['status'], labels: absenceStatusText),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AbsenceDetailScreen(request: r),
                    ),
                  );
                  _reload();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chi tiết đơn: lý do, ảnh/PDF minh chứng, duyệt hoặc từ chối kèm ghi chú.
class AbsenceDetailScreen extends StatefulWidget {
  const AbsenceDetailScreen({
    super.key,
    required this.request,
    this.canReview = true,
  });

  final Map<String, dynamic> request;

  /// false: sinh viên xem đơn của mình, chỉ được hủy khi đơn đang chờ.
  final bool canReview;

  @override
  State<AbsenceDetailScreen> createState() => _AbsenceDetailScreenState();
}

class _AbsenceDetailScreenState extends State<AbsenceDetailScreen> {
  late Map<String, dynamic> _r = widget.request;
  bool _busy = false;

  Future<void> _review(String status) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(approve: status == 'approved'),
    );
    if (note == null) return;
    setState(() => _busy = true);
    try {
      final updated = await Api.post(
        '/api/absence-requests/${_r['id']}/review',
        {'status': status, if (note.isNotEmpty) 'note': note},
      );
      setState(() => _r = Map<String, dynamic>.from(updated));
      if (mounted) {
        showMessage(
          context,
          status == 'approved'
              ? 'Đã duyệt. Buổi học chuyển thành "Có phép".'
              : 'Đã từ chối đơn',
          error: false,
        );
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await confirm(
      context,
      title: 'Hủy đơn xin phép?',
      message: 'Đơn và ảnh minh chứng sẽ bị xóa.',
      action: 'Hủy đơn',
    );
    if (!ok) return;
    try {
      await Api.delete('/api/absence-requests/${_r['id']}');
      if (!mounted) return;
      showMessage(context, 'Đã hủy đơn', error: false);
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final evidence = (_r['evidence'] as List).cast<Map>();
    final pending = _r['status'] == 'pending';

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đơn')),
      bottomNavigationBar: pending && !widget.canReview
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: scheme.error,
                  ),
                  onPressed: _cancel,
                  child: const Text('Hủy đơn'),
                ),
              ),
            )
          : pending
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: scheme.error,
                        ),
                        onPressed: _busy ? null : () => _review('rejected'),
                        child: const Text('Từ chối'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : () => _review('approved'),
                        child: const Text('Duyệt'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: Text(_r['studentName'], style: text.titleLarge)),
              StatusChip(_r['status'], labels: absenceStatusText),
            ],
          ),
          if (_r['studentCode'] != null) Text('Mã SV: ${_r['studentCode']}'),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.event_note_outlined),
                  title: Text(_r['sessionTitle']),
                  subtitle: Text(
                    '${_r['className']} · ${showTime(_r['sessionStart'])}',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text(
                    absenceCategoryText[_r['category']] ?? _r['category'],
                  ),
                  subtitle: Text(_r['reason']),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Gửi lúc'),
                  subtitle: Text(showTime(_r['createdAt'])),
                ),
              ],
            ),
          ),
          if (!pending) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.rate_review_outlined),
                title: Text(
                  '${absenceStatusText[_r['status']]} bởi ${_r['reviewerName'] ?? 'giảng viên'}',
                ),
                subtitle: Text(_r['reviewNote'] ?? 'Không có ghi chú'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Minh chứng (${evidence.length})', style: text.titleMedium),
          const SizedBox(height: 8),
          if (evidence.isEmpty)
            Text(
              'Sinh viên không gửi minh chứng.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          for (final e in evidence)
            e['contentType'] == 'application/pdf'
                ? Card(
                    child: ListTile(
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: Text(e['fileName']),
                      subtitle: Text(
                        '${((e['size'] as num) / 1024).round()} KB',
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        '$baseUrl${e['url']}',
                        headers: {'Authorization': 'Bearer ${Api.token}'},
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => ListTile(
                          leading: const Icon(Icons.broken_image_outlined),
                          title: Text(e['fileName']),
                          subtitle: const Text('Không tải được ảnh'),
                        ),
                      ),
                    ),
                  ),
        ],
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.approve});

  final bool approve;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.approve ? 'Duyệt đơn xin phép?' : 'Từ chối đơn xin phép?',
    ),
    content: TextField(
      controller: _note,
      decoration: InputDecoration(
        labelText: widget.approve
            ? 'Ghi chú cho sinh viên (không bắt buộc)'
            : 'Lý do từ chối',
      ),
      maxLines: 2,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
        onPressed: () => Navigator.pop(context, _note.text.trim()),
        child: Text(widget.approve ? 'Duyệt' : 'Từ chối'),
      ),
    ],
  );
}
