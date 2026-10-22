import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/session.dart';
import 'common.dart';
import 'hutech_logo.dart';

/// Khung trang chủ dùng chung: lời chào, vai trò, danh sách lớp.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.classesTitle,
    required this.emptyText,
    this.onClassTap,
    this.header,
  });

  final String classesTitle;
  final String emptyText;
  final void Function(Map<String, dynamic> cls)? onClassTap;
  final Widget? header;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late Future<List<dynamic>> _classes = _load();

  Future<List<dynamic>> _load() async =>
      await Api.get('/api/classes') as List<dynamic>;

  Future<void> _reload() async {
    setState(() {
      _classes = _load();
    });
    await _classes;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Align(
          alignment: Alignment.centerLeft,
          child: HutechLogo(height: 24),
        ),
        actions: [
          ProfileButton(onChanged: () => setState(() {})),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Xin chào,',
              style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Text(
              Session.fullName,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: RoleChip(Session.role),
            ),
            if (widget.header != null) ...[
              const SizedBox(height: 16),
              widget.header!,
            ],
            const SizedBox(height: 24),
            Text(
              widget.classesTitle,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(
              future: _classes,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return InfoBox(
                    icon: Icons.cloud_off,
                    text: snap.error.toString(),
                    onRetry: _reload,
                  );
                }
                if (snap.data!.isEmpty) {
                  return InfoBox(
                    icon: Icons.school_outlined,
                    text: widget.emptyText,
                  );
                }
                return Column(
                  children: [
                    for (final c in snap.data!)
                      ClassCard(
                        data: c,
                        onTap: widget.onClassTap == null
                            ? null
                            : () => widget.onClassTap!(c),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ClassCard extends StatelessWidget {
  const ClassCard({super.key, required this.data, this.onTap, this.trailing});

  final Map<String, dynamic> data;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = [
      if (data['subject'] != null) data['subject'],
      if (data['room'] != null) 'Phòng ${data['room']}',
      '${data['studentCount']} sinh viên',
    ].join(' · ');
    final teacher = data['teacherName'] == null
        ? 'Chưa phân công giảng viên'
        : 'GV: ${data['teacherName']}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        leading: Container(
          width: 72,
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            data['code'],
            style: TextStyle(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          data['name'],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('$details\n$teacher'),
        isThreeLine: true,
        trailing: trailing,
      ),
    );
  }
}
