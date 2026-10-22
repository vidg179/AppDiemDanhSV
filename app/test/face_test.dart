import 'dart:convert';

import 'package:duonggiavi_diemdanh/core/api.dart';
import 'package:duonggiavi_diemdanh/core/session.dart';
import 'package:duonggiavi_diemdanh/screens/auth/login_screen.dart';
import 'package:duonggiavi_diemdanh/screens/common/face_register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonRes(Object? body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final requests = <http.Request>[];
final hints = <String>[];

Future<List<double>?> fakeCapture(BuildContext context, String hint) async {
  hints.add(hint);
  return [hints.length.toDouble(), 0.5];
}

Map<String, dynamic> me({bool hasFace = false}) => {
  'id': 'sv1',
  'username': 'sv_an',
  'email': 'an@test.vn',
  'fullName': 'Nguyễn Văn An',
  'role': 'student',
  'provider': 'local',
  'hasFace': hasFace,
};

void fakeApi(Future<http.Response> Function(http.Request r) handler) {
  requests.clear();
  hints.clear();
  Api.token = 'test-token';
  Session.user = me();
  Api.client = MockClient((r) async {
    requests.add(r);
    return handler(r);
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  demoLoginTest();

  testWidgets('Đăng ký khuôn mặt: chụp 3 góc, xác nhận mật khẩu', (
    tester,
  ) async {
    fakeApi(
      (r) async => r.method == 'GET'
          ? jsonRes(me(hasFace: true))
          : jsonRes({'samples': 3, 'dimension': 2}),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const FaceRegisterScreen(capture: fakeCapture),
                ),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Chụp'));
      await tester.pumpAndSettle();
    }
    expect(hints, hasLength(3));
    expect(find.text('Đã chụp'), findsNWidgets(3));

    await tester.tap(find.text('Lưu khuôn mặt'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập mật khẩu hiện tại để xác nhận'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Lưu khuôn mặt'));
    await tester.pumpAndSettle();

    final post = requests.firstWhere((r) => r.method == 'POST');
    expect(post.url.path, '/api/users/me/face');
    expect(jsonDecode(post.body), {
      'embeddings': [
        [1.0, 0.5],
        [2.0, 0.5],
        [3.0, 0.5],
      ],
      'password': '123456',
    });
    expect(Session.user!['hasFace'], isTrue);
    expect(find.text('Đã đăng ký khuôn mặt'), findsOneWidget);
  });

  testWidgets('Đăng nhập bằng khuôn mặt cần tên đăng nhập, gửi vector', (
    tester,
  ) async {
    fakeApi(
      (r) async => r.url.path == '/api/classes'
          ? jsonRes([])
          : jsonRes({
              'token': 'jwt',
              'expiresAt': '2026-10-23T00:00:00Z',
              'user': me(hasFace: true),
            }),
    );
    Api.token = null;
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen(capture: fakeCapture)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Đăng nhập bằng khuôn mặt'));
    await tester.tap(find.text('Đăng nhập bằng khuôn mặt'));
    await tester.pumpAndSettle();
    expect(hints, isEmpty);
    expect(requests, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên đăng nhập hoặc email'),
      'sv_an',
    );
    await tester.ensureVisible(find.text('Đăng nhập bằng khuôn mặt'));
    await tester.tap(find.text('Đăng nhập bằng khuôn mặt'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(requests.first.url.path, '/api/auth/face-login');
    expect(jsonDecode(requests.first.body), {
      'username': 'sv_an',
      'embedding': [1.0, 0.5],
    });
    expect(Api.token, 'jwt');
    expect(find.text('Lớp tôi học'), findsOneWidget);
  });
}

void demoLoginTest() {
  testWidgets('Tài khoản demo: đăng nhập xong vào thẳng, không qua màn OTP', (
    tester,
  ) async {
    fakeApi(
      (r) async => r.url.path == '/api/classes'
          ? jsonRes([])
          : jsonRes({
              'token': 'jwt',
              'expiresAt': '2026-10-23T00:00:00Z',
              'user': {...me(), 'role': 'teacher', 'fullName': 'Demo GV'},
            }),
    );
    Api.token = null;
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen(capture: fakeCapture)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên đăng nhập hoặc email'),
      'bnv_gv',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu'),
      'abcd1234',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(requests.first.url.path, '/api/auth/login');
    expect(Api.token, 'jwt');
    expect(find.text('Nhập mã OTP'), findsNothing);
    expect(find.text('Lớp tôi dạy'), findsOneWidget);
  });
}
