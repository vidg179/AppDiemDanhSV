import 'dart:convert';

import 'package:duonggiavi_diemdanh/core/api.dart';
import 'package:duonggiavi_diemdanh/core/session.dart';
import 'package:duonggiavi_diemdanh/screens/teacher/absence_review_screen.dart';
import 'package:duonggiavi_diemdanh/screens/teacher/class_stats_view.dart';
import 'package:duonggiavi_diemdanh/screens/teacher/qr_screen.dart';
import 'package:duonggiavi_diemdanh/screens/teacher/session_detail_screen.dart';
import 'package:duonggiavi_diemdanh/screens/teacher/session_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';

http.Response jsonRes(Object? body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final requests = <http.Request>[];

void fakeApi(Future<http.Response> Function(http.Request r) handler) {
  requests.clear();
  Api.token = 'test-token';
  Session.user = {'id': 'gv1', 'fullName': 'Trần Thị Bình', 'role': 'teacher'};
  Api.client = MockClient((r) async {
    requests.add(r);
    return handler(r);
  });
}

Map lastBody(String method, String path) => jsonDecode(
  requests.lastWhere((r) => r.method == method && r.url.path == path).body,
);

Widget app(Widget home) => MaterialApp(
  locale: const Locale('vi'),
  supportedLocales: const [Locale('vi')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: home,
);

final session = {
  'id': 's1',
  'classId': 'c1',
  'title': 'Buổi 3 - Widget',
  'startTime': DateTime.now().toUtc().toIso8601String(),
  'endTime': DateTime.now()
      .add(const Duration(hours: 1))
      .toUtc()
      .toIso8601String(),
  'latitude': 10.82,
  'longitude': 106.62,
  'radiusMeters': 100,
  'requireFace': false,
};

const cls = {'id': 'c1', 'code': 'LTDD01', 'name': 'Lập trình di động'};

void main() {
  qrFlowTest();
  testWidgets(
    'Tạo buổi học gửi giờ UTC, buổi dài 90 phút, bật yêu cầu khuôn mặt',
    (tester) async {
      fakeApi((r) async => jsonRes({'id': 's1'}));
      await tester.pumpWidget(app(const SessionFormScreen(classId: 'c1')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tiêu đề buổi học'),
        'Buổi 1',
      );
      await tester.tap(find.text('Yêu cầu xác thực khuôn mặt'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Tạo buổi học'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Tạo buổi học'));
      await tester.pumpAndSettle();

      final body = lastBody('POST', '/api/classes/c1/sessions');
      expect(body['title'], 'Buổi 1');
      expect((body['startTime'] as String).endsWith('Z'), isTrue);
      final start = DateTime.parse(body['startTime']);
      final end = DateTime.parse(body['endTime']);
      expect(end.difference(start), const Duration(minutes: 90));
      expect(body.containsKey('latitude'), isFalse);
      expect(body['requireFace'], isTrue);
    },
  );

  testWidgets('Danh sách điểm danh: tổng hợp và điểm danh tay', (tester) async {
    fakeApi((r) async {
      if (r.method == 'POST') return jsonRes({});
      return jsonRes([
        {
          'studentId': 'sv1',
          'fullName': 'Nguyễn Văn An',
          'studentCode': 'SV001',
          'attendanceId': 'a1',
          'status': 'present',
          'method': 'qr',
          'checkInTime': DateTime.now().toUtc().toIso8601String(),
          'note': null,
          'latitude': 10.82,
          'longitude': 106.62,
          'distanceMeters': 12.4,
          'faceVerified': true,
        },
        {
          'studentId': 'sv2',
          'fullName': 'Lê Văn Cường',
          'studentCode': 'SV002',
          'attendanceId': null,
          'status': 'pending',
          'method': null,
          'checkInTime': null,
          'note': null,
          'latitude': null,
          'longitude': null,
          'distanceMeters': null,
          'faceVerified': false,
        },
      ]);
    });
    await tester.pumpWidget(
      app(SessionDetailScreen(session: session, classData: cls)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Có mặt 1/2'), findsOneWidget);
    expect(find.textContaining('cách lớp 12 m'), findsOneWidget);
    expect(find.textContaining('đã xác thực mặt'), findsOneWidget);

    await tester.tap(find.text('Lê Văn Cường'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Vắng'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Ghi chú (không bắt buộc)'),
      'Không báo trước',
    );
    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pumpAndSettle();

    expect(lastBody('POST', '/api/attendance'), {
      'sessionId': 's1',
      'studentId': 'sv2',
      'status': 'absent',
      'note': 'Không báo trước',
    });
    expect(find.text('Đã lưu: Lê Văn Cường - Vắng'), findsOneWidget);
  });

  testWidgets('Chiếu QR: tạo mã khi mở và đếm ngược', (tester) async {
    fakeApi(
      (r) async => jsonRes({
        'sessionId': 's1',
        'qrToken': 'ABC123',
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 1))
            .toUtc()
            .toIso8601String(),
      }),
    );
    await tester.pumpWidget(app(QrScreen(session: session)));
    await tester.pump();
    await tester.pump();

    expect(lastBody('POST', '/api/sessions/s1/qr'), {'validMinutes': 1});
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining(RegExp(r'^(00:[56]\d|01:00)$')), findsOneWidget);

    await tester.pumpWidget(const SizedBox()); // đóng màn hình để dừng đồng hồ
  });

  testWidgets('Thống kê: đưa sinh viên bị cảnh báo lên đầu', (tester) async {
    fakeApi(
      (r) async => jsonRes({
        'classId': 'c1',
        'totalSessions': 5,
        'warningThresholdPercent': 20,
        'students': [
          {
            'studentId': 'sv1',
            'fullName': 'Nguyễn Văn An',
            'studentCode': 'SV001',
            'present': 5,
            'late': 0,
            'excused': 0,
            'absent': 0,
            'absentPercent': 0,
            'warning': false,
          },
          {
            'studentId': 'sv2',
            'fullName': 'Lê Văn Cường',
            'studentCode': 'SV002',
            'present': 2,
            'late': 1,
            'excused': 0,
            'absent': 2,
            'absentPercent': 40,
            'warning': true,
          },
        ],
      }),
    );
    await tester.pumpWidget(
      app(const Scaffold(body: ClassStatsView(classId: 'c1'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cảnh báo vắng'), findsOneWidget);
    expect(find.text('Vắng 40%'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    final cuong = tester.getTopLeft(find.text('Lê Văn Cường')).dy;
    final an = tester.getTopLeft(find.text('Nguyễn Văn An')).dy;
    expect(cuong < an, isTrue);
  });

  testWidgets('Duyệt đơn xin phép kèm ghi chú', (tester) async {
    final request = {
      'id': 'r1',
      'studentId': 'sv2',
      'studentName': 'Lê Văn Cường',
      'studentCode': 'SV002',
      'classId': 'c1',
      'className': 'Lập trình di động',
      'sessionId': 's1',
      'sessionTitle': 'Buổi 3',
      'sessionStart': DateTime.now().toUtc().toIso8601String(),
      'category': 'sick',
      'reason': 'Bị sốt',
      'status': 'pending',
      'evidence': [
        {
          'id': 'e1',
          'fileName': 'giay-kham.pdf',
          'contentType': 'application/pdf',
          'size': 20480,
          'url': '/api/absence-requests/r1/evidence/e1',
        },
      ],
      'reviewerName': null,
      'reviewNote': null,
      'reviewedAt': null,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    fakeApi((r) async {
      if (r.method == 'POST') {
        return jsonRes({
          ...request,
          'status': 'approved',
          'reviewerName': 'Trần Thị Bình',
          'reviewNote': 'Mau khỏe',
        });
      }
      return jsonRes([request]);
    });
    await tester.pumpWidget(app(const AbsenceReviewScreen()));
    await tester.pumpAndSettle();
    expect(requests.first.url.queryParameters['status'], 'pending');

    await tester.tap(find.text('Lê Văn Cường'));
    await tester.pumpAndSettle();
    expect(find.text('giay-kham.pdf'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Duyệt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Mau khỏe');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Duyệt'),
      ),
    );
    await tester.pumpAndSettle();

    expect(lastBody('POST', '/api/absence-requests/r1/review'), {
      'status': 'approved',
      'note': 'Mau khỏe',
    });
    expect(find.text('Đã duyệt'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Duyệt'), findsNothing);
  });
}

void qrFlowTest() {
  testWidgets(
    'Hết 60s: QR tắt, hiện danh sách; tạo mã mới; điểm danh tay và lưu',
    (tester) async {
      var qrCalls = 0;
      fakeApi((r) async {
        if (r.url.path == '/api/sessions/s1/qr') {
          qrCalls++;
          // Lần 1: mã đã hết hạn ngay; lần 2: còn hạn 1 phút.
          final expires = qrCalls == 1
              ? DateTime.now().subtract(const Duration(seconds: 1))
              : DateTime.now().add(const Duration(minutes: 1));
          return jsonRes({
            'sessionId': 's1',
            'qrToken': 'TOKEN$qrCalls',
            'expiresAt': expires.toUtc().toIso8601String(),
          });
        }
        if (r.method == 'POST') return jsonRes({});
        return jsonRes([
          {
            'studentId': 'sv1',
            'fullName': 'An',
            'studentCode': 'SV1',
            'status': 'present',
            'method': 'qr',
            'checkInTime': DateTime.now().toUtc().toIso8601String(),
            'note': null,
            'latitude': null,
            'longitude': null,
            'distanceMeters': null,
            'faceVerified': false,
          },
          {
            'studentId': 'sv2',
            'fullName': 'Bình',
            'studentCode': 'SV2',
            'status': 'pending',
            'method': null,
            'checkInTime': null,
            'note': null,
            'latitude': null,
            'longitude': null,
            'distanceMeters': null,
            'faceVerified': false,
          },
        ]);
      });
      await tester.pumpWidget(app(QrScreen(session: session)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Mã QR đã tắt'), findsOneWidget);
      expect(
        find.textContaining('Còn 1 sinh viên chưa điểm danh'),
        findsOneWidget,
      );
      // sinh viên chưa điểm danh được xếp lên đầu
      expect(
        tester.getTopLeft(find.text('Bình')).dy <
            tester.getTopLeft(find.text('An')).dy,
        isTrue,
      );

      // điểm danh tay cho sinh viên bị lỗi rồi lưu
      await tester.tap(find.text('Bình'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Có mặt'));
      await tester.tap(find.text('Lưu điểm danh'));
      await tester.pumpAndSettle();
      expect(lastBody('POST', '/api/attendance'), {
        'sessionId': 's1',
        'studentId': 'sv2',
        'status': 'present',
      });
      expect(find.text('Đã lưu: Bình - Có mặt'), findsOneWidget);

      // tạo mã mới cho người chưa kịp quét
      await tester.tap(find.text('Tạo mã mới (60 giây)'));
      await tester.pumpAndSettle();
      expect(qrCalls, 2);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Mã: TOKEN2'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    },
  );
}
