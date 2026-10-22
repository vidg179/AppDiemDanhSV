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
            minimumSize: const Size(0, 44),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Chữ cái đầu của tên trên nền trung tính (không tô màu nhấn).
class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.radius = 20});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.surfaceContainerHighest,
      child: Text(
        initials(name),
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

/// Avatar trên AppBar: mở Hồ sơ, đăng xuất thì quay về màn đăng nhập.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key, this.onChanged, this.onBrand = false});

  final VoidCallback? onChanged;

  /// Đặt trên nền xanh HUTECH: avatar trắng, chữ xanh.
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Hồ sơ',
      icon: onBrand
          ? CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Text(
                initials(Session.fullName),
                style: const TextStyle(
                  color: brandBlueDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Avatar(Session.fullName, radius: 18),
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

/// Nhãn bo tròn: nền nhạt, chữ đậm cùng tông.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 12.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Cặp màu (nền nhạt, chữ đậm) cho một trạng thái hoặc vai trò.
({Color bg, Color fg}) _tone(BuildContext context, String key) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (key) {
    'present' || 'approved' || 'teacher' =>
      dark
          ? (bg: const Color(0xFF163A23), fg: const Color(0xFFA8E5BC))
          : (bg: const Color(0xFFDDF3E4), fg: const Color(0xFF0E5A2A)),
    'late' =>
      dark
          ? (bg: const Color(0xFF3D2C0A), fg: const Color(0xFFFFD58A))
          : (bg: const Color(0xFFFFEFCC), fg: const Color(0xFF7A4A00)),
    'absent' || 'rejected' || 'admin' =>
      dark
          ? (bg: const Color(0xFF44181A), fg: const Color(0xFFFFB4B0))
          : (bg: const Color(0xFFFCE1E1), fg: const Color(0xFF8E1414)),
    'excused' || 'student' =>
      dark
          ? (bg: const Color(0xFF12324B), fg: const Color(0xFFCFE6F8))
          : (bg: const Color(0xFFDCEBF7), fg: const Color(0xFF023A63)),
    _ =>
      dark
          ? (bg: const Color(0xFF2C2E33), fg: const Color(0xFFC9CDD3))
          : (bg: const Color(0xFFE6EAEF), fg: const Color(0xFF3F4A56)),
  };
}

class RoleChip extends StatelessWidget {
  const RoleChip(this.role, {super.key});

  final String role;

  @override
  Widget build(BuildContext context) {
    final t = _tone(context, role);
    return Pill(
      label: roleText[role] ?? role,
      background: t.bg,
      foreground: t.fg,
    );
  }
}

/// Màu đậm của trạng thái (chấm trên bản đồ, biểu tượng).
Color statusColor(BuildContext context, String status) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (status) {
    'present' ||
    'approved' => dark ? const Color(0xFF7BD497) : const Color(0xFF16803C),
    'late' => dark ? const Color(0xFFFFC857) : const Color(0xFFB86E00),
    'absent' ||
    'rejected' => dark ? const Color(0xFFFF8A80) : const Color(0xFFC4141F),
    'excused' => dark ? const Color(0xFF6AB3EA) : brandColor,
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
    final t = _tone(context, status);
    return Pill(
      label: labels[status] ?? status,
      background: t.bg,
      foreground: t.fg,
    );
  }
}

/// Nút điểm danh: vàng khiên HUTECH, chỉ dùng cho hành động điểm danh.
class AttendanceButton extends StatelessWidget {
  const AttendanceButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.tertiary,
      foregroundColor: onBrandYellow,
      minimumSize: const Size.fromHeight(56),
      textStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    onPressed: onPressed,
    icon: Icon(icon, size: 24),
    label: Text(label),
  );
}

/// Ô ngày cho danh sách buổi học: số ngày lớn, thứ nhỏ bên dưới.
class DateBlock extends StatelessWidget {
  const DateBlock(this.date, {super.key});

  final DateTime date;

  static const _weekday = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 44,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 22,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              '${_weekday[date.weekday - 1]} · ${date.month}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung trống / lỗi: giữ khung, một câu, có nút thử lại khi cần.
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: scheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 4),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
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
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 96),
          children: children,
        );
      },
    ),
  );
}
