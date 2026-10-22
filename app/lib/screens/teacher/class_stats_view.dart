import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../widgets/common.dart';

/// Thống kê chuyên cần của lớp. Sinh viên vắng từ ngưỡng cảnh báo trở lên được đưa lên đầu, tô đỏ.
class ClassStatsView extends StatefulWidget {
  const ClassStatsView({super.key, required this.classId});

  final String classId;

  @override
  State<ClassStatsView> createState() => _ClassStatsViewState();
}

class _ClassStatsViewState extends State<ClassStatsView> {
  late Future<Map<String, dynamic>> _stats = _load();

  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(
    await Api.get('/api/classes/${widget.classId}/attendance/stats'),
  );

  Future<void> _reload() async {
    setState(() {
      _stats = _load();
    });
    await _stats;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _stats,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(
              children: [
                InfoBox(
                  icon: Icons.cloud_off,
                  text: snap.error.toString(),
                  onRetry: _reload,
                ),
              ],
            );
          }
          final data = snap.data!;
          final total = data['totalSessions'] as int;
          final threshold = (data['warningThresholdPercent'] as num).round();
          final rows = [...(data['students'] as List)]
            ..sort(
              (a, b) => (b['absentPercent'] as num).compareTo(
                a['absentPercent'] as num,
              ),
            );
          final warned = rows.where((r) => r['warning'] == true).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Row(
                children: [
                  _Tile(label: 'Buổi đã học', value: '$total'),
                  const SizedBox(width: 12),
                  _Tile(label: 'Sinh viên', value: '${rows.length}'),
                  const SizedBox(width: 12),
                  _Tile(
                    label: 'Cảnh báo vắng',
                    value: '$warned',
                    alert: warned > 0,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Cảnh báo khi vắng từ $threshold% số buổi trở lên (không tính buổi có phép).',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const InfoBox(
                  icon: Icons.groups_outlined,
                  text: 'Lớp chưa có sinh viên.',
                )
              else
                for (final r in rows)
                  _StudentRow(row: Map<String, dynamic>.from(r)),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.alert = false});

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: alert
              ? scheme.errorContainer
              : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: alert ? scheme.onErrorContainer : null,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: alert
                    ? scheme.onErrorContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final warn = row['warning'] == true;
    final percent = (row['absentPercent'] as num).toDouble();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: warn ? scheme.errorContainer.withValues(alpha: 0.5) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (warn)
                  Icon(
                    Icons.warning_amber_rounded,
                    color: scheme.error,
                    size: 20,
                  ),
                if (warn) const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    row['fullName'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  'Vắng ${percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1)}%',
                  style: TextStyle(
                    color: warn ? scheme.error : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                StatusChip(
                  'present',
                  labels: {'present': 'Có mặt ${row['present']}'},
                ),
                StatusChip('late', labels: {'late': 'Trễ ${row['late']}'}),
                StatusChip(
                  'excused',
                  labels: {'excused': 'Có phép ${row['excused']}'},
                ),
                StatusChip(
                  'absent',
                  labels: {'absent': 'Vắng ${row['absent']}'},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
