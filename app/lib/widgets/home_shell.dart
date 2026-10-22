import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/ui.dart';
import 'common.dart';
import 'hutech_logo.dart';

/// Đầu trang màu xanh HUTECH: logo, tên người dùng, vai trò, vạch vàng khiên bên dưới.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onProfileChanged,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onProfileChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: brandBlueDeep,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 12,
              8,
              22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const HutechLogo(height: 26),
                    const Spacer(),
                    ProfileButton(onBrand: true, onChanged: onProfileChanged),
                  ],
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    title,
                    style: text.headlineMedium?.copyWith(color: Colors.white),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: text.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(height: 6, color: brandYellow),
        ],
      ),
    );
  }
}

/// Khung trang chủ dùng chung: đầu trang HUTECH, hành động chính, danh sách lớp.
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
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            BrandHeader(
              title: Session.fullName,
              subtitle: roleText[Session.role],
              onProfileChanged: () => setState(() {}),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?widget.header,
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      4,
                      widget.header == null ? 4 : 28,
                      4,
                      10,
                    ),
                    child: Text(widget.classesTitle, style: text.titleLarge),
                  ),
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
          ],
        ),
      ),
    );
  }
}

/// Lối tắt trên trang chủ: thẻ trắng, tiêu đề + một dòng mô tả, mũi tên.
class ShortcutCard extends StatelessWidget {
  const ShortcutCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
      leading: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class ClassCard extends StatelessWidget {
  const ClassCard({super.key, required this.data, this.onTap, this.trailing});

  final Map<String, dynamic> data;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final where = [
      data['code'],
      if (data['subject'] != null) data['subject'],
      if (data['room'] != null) 'Phòng ${data['room']}',
    ].join(' · ');
    final teacher = data['teacherName'] == null
        ? 'Chưa phân công giảng viên'
        : 'GV ${data['teacherName']}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 16, trailing == null ? 12 : 4, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'],
                      style: text.titleMedium?.copyWith(height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(where, style: muted),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '${data['studentCount']}',
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(' sinh viên', style: muted),
                        Text('  ·  ', style: muted),
                        Flexible(
                          child: Text(
                            teacher,
                            style: muted,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing ??
                  (onTap == null
                      ? const SizedBox.shrink()
                      : Icon(
                          Icons.chevron_right,
                          color: scheme.onSurfaceVariant,
                        )),
            ],
          ),
        ),
      ),
    );
  }
}
