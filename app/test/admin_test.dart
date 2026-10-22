import 'dart:convert';

import 'package:duonggiavi_diemdanh/core/api.dart';
import 'package:duonggiavi_diemdanh/core/session.dart';
import 'package:duonggiavi_diemdanh/screens/admin/classes_screen.dart';
import 'package:duonggiavi_diemdanh/screens/admin/users_screen.dart';
import 'package:duonggiavi_diemdanh/screens/common/class_students_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonRes(Object? body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> user(
  String id,
  String name,
  String role, {
  String? code,
}) => {
  'id': id,
  'username': id,
  'email': '$id@test.vn',
  'fullName': name,
  'phone': null,
  'role': role,
  'studentCode': code,
  'emailVerified': true,
  'provider': 'local',
  'hasFace': false,
  'createdAt': '2026-10-22T00:00:00Z',
};

final admin = user('admin1', 'Quản trị viên', 'admin');
final teacher = user('gv_binh', 'Trần Thị Bình', 'teacher');
final student = user('sv_an', 'Nguyễn Văn An', 'student', code: 'SV001');
final student2 = user('sv_cuong', 'Lê Văn Cường', 'student', code: 'SV002');

final requests = <http.Request>[];

void fakeApi(Future<http.Response> Function(http.Request r) handler) {
  requests.clear();
  Api.token = 'test-token';
  Session.user = admin;
  Api.client = MockClient((r) async {
    requests.add(r);
    return handler(r);
  });
}

http.Request lastRequest(String method, String path) =>
    requests.lastWhere((r) => r.method == method && r.url.path == path);

Future<void> fill(WidgetTester tester, String label, String text) =>
    tester.enterText(find.widgetWithText(TextFormField, label), text);

void main() {
  testWidgets('Danh sách người dùng hiện đủ và lọc theo vai trò', (
    tester,
  ) async {
    fakeApi((r) async {
      final role = r.url.queryParameters['role'];
      final all = [admin, teacher, student];
      return jsonRes(
        role == null ? all : all.where((u) => u['role'] == role).toList(),
      );
    });

    await tester.pumpWidget(const MaterialApp(home: UsersScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Trần Thị Bình'), findsOneWidget);
    expect(find.text('Nguyễn Văn An'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Giảng viên'));
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters['role'], 'teacher');
    expect(find.text('Trần Thị Bình'), findsOneWidget);
    expect(find.text('Nguyễn Văn An'), findsNothing);
  });

  testWidgets('Xóa người dùng phải xác nhận, không xóa được chính mình', (
    tester,
  ) async {
    fakeApi(
      (r) async => r.method == 'DELETE'
          ? http.Response('', 204)
          : jsonRes([admin, teacher, student]),
    );

    await tester.pumpWidget(const MaterialApp(home: UsersScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Thao tác').at(0)); // dòng của chính admin
    await tester.pumpAndSettle();
    expect(find.text('Xóa'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Thao tác').at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa Nguyễn Văn An?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(lastRequest('DELETE', '/api/users/sv_an'), isNotNull);
    expect(find.text('Đã xóa Nguyễn Văn An'), findsOneWidget);
  });

  testWidgets('Thêm người dùng: kiểm tra form và chỉ gửi trường có giá trị', (
    tester,
  ) async {
    fakeApi(
      (r) async => r.method == 'POST' ? jsonRes(student) : jsonRes([admin]),
    );

    await tester.pumpWidget(const MaterialApp(home: UsersScreen()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Thêm người dùng'),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Thêm người dùng'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm người dùng'));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu ít nhất 6 ký tự'), findsOneWidget);
    expect(find.text('Nhập họ và tên'), findsOneWidget);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);

    await fill(tester, 'Tên đăng nhập', 'sv_an');
    await fill(tester, 'Họ và tên', 'Nguyễn Văn An');
    await fill(tester, 'Email', 'an@test.vn');
    await fill(tester, 'Mật khẩu', '123456');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Thêm người dùng'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm người dùng'));
    await tester.pumpAndSettle();

    final body = jsonDecode(lastRequest('POST', '/api/users').body) as Map;
    expect(body, {
      'username': 'sv_an',
      'email': 'an@test.vn',
      'fullName': 'Nguyễn Văn An',
      'role': 'student',
      'password': '123456',
    });
    expect(find.text('Đã thêm Nguyễn Văn An'), findsOneWidget);
    expect(find.byType(UsersScreen), findsOneWidget);
  });

  testWidgets('Sửa người dùng: để trống mật khẩu thì không gửi newPassword', (
    tester,
  ) async {
    fakeApi(
      (r) async =>
          r.method == 'PUT' ? jsonRes(teacher) : jsonRes([admin, teacher]),
    );

    await tester.pumpWidget(const MaterialApp(home: UsersScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trần Thị Bình'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa người dùng'), findsOneWidget);

    await fill(tester, 'Họ và tên', 'Trần Thị Bình B');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Lưu thay đổi'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu thay đổi'));
    await tester.pumpAndSettle();

    final body =
        jsonDecode(lastRequest('PUT', '/api/users/gv_binh').body) as Map;
    expect(body['fullName'], 'Trần Thị Bình B');
    expect(body['role'], 'teacher');
    expect(body.containsKey('newPassword'), isFalse);
  });

  testWidgets('Tạo lớp có chọn giảng viên', (tester) async {
    fakeApi((r) async {
      if (r.url.path == '/api/users') return jsonRes([teacher]);
      if (r.method == 'POST') return jsonRes({'id': 'c1'});
      return jsonRes([]);
    });

    await tester.pumpWidget(const MaterialApp(home: ClassesScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có lớp học nào'), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Thêm lớp'));
    await tester.pumpAndSettle();
    await fill(tester, 'Mã lớp', 'LTDD01');
    await fill(tester, 'Tên lớp', 'Lập trình di động');
    await fill(tester, 'Phòng học (không bắt buộc)', 'A101');

    await tester.tap(find.text('Chưa phân công'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trần Thị Bình (@gv_binh)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Tạo lớp'));
    await tester.pumpAndSettle();

    final body = jsonDecode(lastRequest('POST', '/api/classes').body) as Map;
    expect(body, {
      'code': 'LTDD01',
      'name': 'Lập trình di động',
      'room': 'A101',
      'teacherId': 'gv_binh',
    });
    expect(find.text('Đã tạo lớp LTDD01'), findsOneWidget);
  });

  testWidgets('Thêm sinh viên vào lớp, ẩn sinh viên đã có trong lớp', (
    tester,
  ) async {
    fakeApi((r) async {
      if (r.url.path == '/api/users') return jsonRes([student, student2]);
      if (r.method == 'POST') return jsonRes({});
      return jsonRes([student2]); // lớp đang có Cường
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ClassStudentsScreen(
          classData: {
            'id': 'c1',
            'code': 'LTDD01',
            'name': 'Lập trình di động',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lê Văn Cường'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Thêm sinh viên'),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CheckboxListTile, 'Lê Văn Cường'), findsNothing);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Nguyễn Văn An'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm 1 sinh viên'));
    await tester.pumpAndSettle();

    final body =
        jsonDecode(lastRequest('POST', '/api/classes/c1/students').body) as Map;
    expect(body['studentIds'], ['sv_an']);
    expect(find.text('Đã thêm 1 sinh viên vào lớp'), findsOneWidget);
  });
}
