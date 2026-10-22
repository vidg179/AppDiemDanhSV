import 'package:flutter/material.dart';

/// Màu nhận diện HUTECH (lấy từ logo trường).
const brandColor = Color(0xFF016BB5); // xanh HUTECH
const brandYellow = Color(0xFFFFED00); // vàng khiên
const brandRed = Color(0xFFE30613); // đỏ chữ "Đại học Công nghệ"

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: brandColor,
    brightness: brightness,
  );
  final scheme = base.copyWith(
    // Chế độ sáng dùng đúng màu xanh của logo; chế độ tối dùng xanh sáng hơn cho đủ tương phản.
    primary: dark ? base.primary : brandColor,
    onPrimary: dark ? base.onPrimary : Colors.white,
    tertiary: dark ? brandYellow : const Color(0xFF6B6200),
    tertiaryContainer: dark ? const Color(0xFF4A4400) : const Color(0xFFFFF7A8),
    onTertiaryContainer: dark
        ? const Color(0xFFFFF7A8)
        : const Color(0xFF3A3500),
  );
  const barColor = Color(0xFF015A99); // xanh HUTECH đậm cho thanh tiêu đề
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: barColor,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Color(0xFFBFD9EE),
      indicatorColor: brandYellow,
      dividerColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primaryContainer,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
  );
}

void showMessage(BuildContext context, String message, {bool error = true}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? scheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

const roleText = {
  'admin': 'Quản trị viên',
  'teacher': 'Giảng viên',
  'student': 'Sinh viên',
};

const statusText = {
  'present': 'Có mặt',
  'late': 'Trễ',
  'absent': 'Vắng',
  'excused': 'Có phép',
  'pending': 'Chưa điểm danh',
};

final usernamePattern = RegExp(r'^[a-zA-Z0-9_.]{3,30}$');
final phonePattern = RegExp(r'^\+?[0-9]{9,15}$');
final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? requiredField(String? v, String label) =>
    (v == null || v.trim().isEmpty) ? 'Nhập $label' : null;

String? validatePassword(String? v) =>
    (v == null || v.length < 6) ? 'Mật khẩu ít nhất 6 ký tự' : null;
