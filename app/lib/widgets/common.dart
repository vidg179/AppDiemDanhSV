import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/ui.dart';
import '../screens/auth/login_screen.dart';
import '../screens/common/profile_screen.dart';

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.isEmpty || parts.last.isEmpty
      ? '?'
      : parts.last[0].toUpperCase();
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Xóa',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
            minimumSize: const Size(0, 40),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Avatar trên AppBar: mở Hồ sơ, đăng xuất thì quay về màn đăng nhập.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'Hồ sơ',
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: scheme.primaryContainer,
        child: Text(
          initials(Session.fullName),
          style: TextStyle(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        if (!context.mounted) return;
        if (Session.user == null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        } else {
          onChanged?.call();
        }
      },
    );
  }
}

class RoleChip extends StatelessWidget {
  const RoleChip(this.role, {super.key});

  final String role;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (role) {
      'admin' => dark ? Colors.deepPurple.shade200 : Colors.deepPurple,
      'teacher' => dark ? Colors.orange.shade300 : Colors.deepOrange.shade700,
      _ => dark ? Colors.lightBlue.shade200 : brandColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        roleText[role] ?? role,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Color statusColor(BuildContext context, String status) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (status) {
    'present' ||
    'approved' => dark ? Colors.green.shade300 : Colors.green.shade700,
    'late' => dark ? Colors.amber.shade300 : Colors.orange.shade800,
    'absent' || 'rejected' => dark ? Colors.red.shade300 : Colors.red.shade700,
    'excused' => dark ? Colors.lightBlue.shade200 : Colors.blue.shade700,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}

const absenceStatusText = {
  'pending': 'Chờ duyệt',
  'approved': 'Đã duyệt',
  'rejected': 'Từ chối',
};

const absenceCategoryText = {
  'sick': 'Ốm đau',
  'family': 'Việc gia đình',
  'event': 'Hoạt động trường',
  'other': 'Lý do khác',
};

/// Chip trạng thái điểm danh hoặc trạng thái đơn.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.labels = statusText});

  final String status;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        labels[status] ?? status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class InfoBox extends StatelessWidget {
  const InfoBox({
    super.key,
    required this.icon,
    required this.text,
    this.onRetry,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

/// Hiển thị một Future danh sách: đang tải / lỗi / rỗng / có dữ liệu, kéo xuống để tải lại.
class AsyncListView extends StatelessWidget {
  const AsyncListView({
    super.key,
    required this.future,
    required this.onRefresh,
    required this.emptyIcon,
    required this.emptyText,
    required this.itemBuilder,
  });

  final Future<List<dynamic>> future;
  final Future<void> Function() onRefresh;
  final IconData emptyIcon;
  final String emptyText;
  final Widget Function(BuildContext context, Map<String, dynamic> item)
  itemBuilder;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snap) {
        final List<Widget> children;
        if (snap.connectionState != ConnectionState.done) {
          children = const [
            Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
          ];
        } else if (snap.hasError) {
          children = [
            InfoBox(
              icon: Icons.cloud_off,
              text: snap.error.toString(),
              onRetry: onRefresh,
            ),
          ];
        } else if (snap.data!.isEmpty) {
          children = [InfoBox(icon: emptyIcon, text: emptyText)];
        } else {
          children = [
            for (final item in snap.data!)
              itemBuilder(context, Map<String, dynamic>.from(item)),
          ];
        }
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          children: children,
        );
      },
    ),
  );
}
