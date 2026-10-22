import 'package:flutter/material.dart';

/// Màu nhận diện HUTECH (lấy từ logo trường).
const brandColor = Color(0xFF016BB5); // xanh HUTECH
const brandYellow = Color(0xFFFFED00); // vàng khiên
const brandRed = Color(0xFFE30613); // đỏ chữ "Đại học Công nghệ"
const brandBlueDeep = Color(0xFF01579A); // nền đầu trang
const onBrandYellow = Color(0xFF1A1A00); // chữ trên nền vàng

/// Bảng màu: nền xám xanh lạnh, thẻ trắng một bậc sáng hơn, chữ mực đậm.
/// Xanh HUTECH cho nút chính; vàng HUTECH chỉ dành cho hành động điểm danh.
class _Palette {
  const _Palette({
    required this.ground,
    required this.card,
    required this.field,
    required this.raised,
    required this.ink,
    required this.muted,
    required this.line,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.yellow,
    required this.yellowSoft,
    required this.onYellowSoft,
    required this.error,
  });

  final Color ground, card, field, raised, ink, muted, line;
  final Color primary, onPrimary, primarySoft, onPrimarySoft;
  final Color yellow, yellowSoft, onYellowSoft, error;
}

const _light = _Palette(
  ground: Color(0xFFF3F5F8),
  card: Color(0xFFFFFFFF),
  field: Color(0xFFE8ECF1),
  raised: Color(0xFFE2E7EE),
  ink: Color(0xFF0F1B2A),
  muted: Color(0xFF566270),
  line: Color(0xFFDDE2E8),
  primary: brandColor,
  onPrimary: Colors.white,
  primarySoft: Color(0xFFDCEBF7),
  onPrimarySoft: Color(0xFF023A63),
  yellow: brandYellow,
  yellowSoft: Color(0xFFFFF7B3),
  onYellowSoft: Color(0xFF3D3800),
  error: Color(0xFFC4141F),
);

const _dark = _Palette(
  ground: Color(0xFF0F1012),
  card: Color(0xFF1A1B1E),
  field: Color(0xFF24262A),
  raised: Color(0xFF2C2E33),
  ink: Color(0xFFF2F2F2),
  muted: Color(0xFFA9ADB3),
  line: Color(0xFF2E3034),
  primary: Color(0xFF6AB3EA),
  onPrimary: Color(0xFF02233D),
  primarySoft: Color(0xFF12324B),
  onPrimarySoft: Color(0xFFCFE6F8),
  yellow: Color(0xFFFFE600),
  yellowSoft: Color(0xFF3A3600),
  onYellowSoft: Color(0xFFFFF3A0),
  error: Color(0xFFFF8A80),
);

const fontFamily = 'BeVietnamPro';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? _dark : _light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: brandColor,
        brightness: brightness,
      ).copyWith(
        primary: p.primary,
        onPrimary: p.onPrimary,
        primaryContainer: p.primarySoft,
        onPrimaryContainer: p.onPrimarySoft,
        secondaryContainer: p.raised,
        onSecondaryContainer: p.ink,
        tertiary: p.yellow,
        onTertiary: onBrandYellow,
        tertiaryContainer: p.yellowSoft,
        onTertiaryContainer: p.onYellowSoft,
        error: p.error,
        surface: p.ground,
        onSurface: p.ink,
        onSurfaceVariant: p.muted,
        surfaceContainerLowest: p.card,
        surfaceContainerLow: p.card,
        surfaceContainer: p.card,
        surfaceContainerHigh: p.card,
        surfaceContainerHighest: p.raised,
        outline: p.muted,
        outlineVariant: p.line,
        surfaceTint: Colors.transparent,
      );

  // Ít cỡ chữ, cách xa nhau: 32 / 22 / 17 / 15 / 13.
  final base = ThemeData(
    brightness: brightness,
    fontFamily: fontFamily,
  ).textTheme.apply(bodyColor: p.ink, displayColor: p.ink);
  final textTheme = base.copyWith(
    headlineMedium: base.headlineMedium?.copyWith(
      fontSize: 30,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
    bodySmall: base.bodySmall?.copyWith(fontSize: 13, color: p.muted),
    labelLarge: base.labelLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
  );

  const pill = StadiumBorder();
  final soft = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: fontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: p.ground,
    canvasColor: p.ground,
    dividerTheme: DividerThemeData(color: p.line, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.ground,
      foregroundColor: p.ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.ink,
      unselectedLabelColor: p.muted,
      indicatorColor: p.ink,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: p.line,
      labelStyle: const TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      indicatorColor: p.raised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? p.ink : p.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? p.ink : p.muted,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.error, width: 2),
      ),
      labelStyle: TextStyle(color: p.muted),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (s) => TextStyle(
          color: s.contains(WidgetState.error)
              ? p.error
              : s.contains(WidgetState.focused)
              ? p.primary
              : p.muted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: pill,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: pill,
        foregroundColor: p.ink,
        side: BorderSide(color: p.line, width: 1.5),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: pill,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: pill,
      extendedTextStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.field,
      selectedColor: p.primarySoft,
      side: BorderSide.none,
      shape: pill,
      labelStyle: TextStyle(
        fontFamily: fontFamily,
        color: p.ink,
        fontWeight: FontWeight.w500,
      ),
      checkmarkColor: p.onPrimarySoft,
    ),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: soft,
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.muted,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: p.ink,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13.5,
        height: 1.4,
        color: p.muted,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(fontFamily: fontFamily, color: p.ground),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
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
