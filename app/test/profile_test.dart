import 'package:duonggiavi_diemdanh/core/session.dart';
import 'package:duonggiavi_diemdanh/core/ui.dart';
import 'package:duonggiavi_diemdanh/screens/common/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app() => MaterialApp(
  theme: buildTheme(Brightness.light),
  home: const ProfileScreen(),
);

void main() {
  for (final hasFace in [false, true]) {
    testWidgets('Hồ sơ hiển thị trên màn hình điện thoại (hasFace=$hasFace)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      Session.user = {
        'username': 'sv_an',
        'email': 'an@test.vn',
        'fullName': 'Nguyễn Văn An',
        'role': 'student',
        'studentCode': 'SV001',
        'phone': '0901234567',
        'emailVerified': true,
        'hasFace': hasFace,
      };
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('Khuôn mặt'), findsOneWidget);
      expect(find.text(hasFace ? 'Đăng ký lại' : 'Đăng ký'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.widgetWithText(TextButton, 'Đăng xuất'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Đăng xuất'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Đăng xuất'));
      await tester.pumpAndSettle();
      expect(find.text('Đăng xuất?'), findsOneWidget);
    });
  }
}
