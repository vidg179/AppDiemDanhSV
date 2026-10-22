import 'dart:convert';
import 'dart:typed_data';

import 'package:duonggiavi_diemdanh/core/api.dart';
import 'package:duonggiavi_diemdanh/core/session.dart';
import 'package:duonggiavi_diemdanh/screens/student/absence_form_screen.dart';
import 'package:duonggiavi_diemdanh/screens/student/scan_screen.dart';
import 'package:duonggiavi_diemdanh/screens/student/student_class_screen.dart';
import 'package:duonggiavi_diemdanh/screens/teacher/absence_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonRes(Object? body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final requests = <http.Request>[];

void fakeApi(Future<http.Response> Function(http.Request r) handler) {
  requests.clear();
  Api.token = 'test-token';
  Session.user = {'id': 'sv1', 'fullName': 'Nguyễn Văn An', 'role': 'student'};
  Api.client = MockClient((r) async {
    requests.add(r);
    return handler(r);
  });
}

Widget app(Widget home) => MaterialApp(
  locale: const Locale('vi'),
  supportedLocales: const [Locale('vi')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: home,
);

String iso(Duration offset) =>
    DateTime.now().add(offset).toUtc().toIso8601String();

Map<String, dynamic> session(String id, String title, Duration startOffset) => {
  'id': id,
  'classId': 'c1',
  'title': title,
  'startTime': iso(startOffset),
  'endTime': iso(startOffset + const Duration(minutes: 90)),
  'latitude': null,
  'longitude': null,
  'radiusMeters': 100,
  'requireFace': false,
};

void main() {
  test('Điểm danh gửi mã QR kèm vị trí', () async {
    fakeApi(
      (r) async =>
          jsonRes({'status': 'present', 'checkInTime': iso(Duration.zero)}),
    );
    await submitCheckIn(' ABC123 ', latitude: 10.8, longitude: 106.6);
    expect(jsonDecode(requests.last.body), {
      'qrToken': 'ABC123',
      'latitude': 10.8,
      'longitude': 106.6,
    });
  });

  test('Điểm danh không có GPS thì không gửi tọa độ', () async {
    fakeApi(
      (r) async =>
          jsonRes({'status': 'present', 'checkInTime': iso(Duration.zero)}),
    );
    await submitCheckIn('ABC123');
    expect(jsonDecode(requests.last.body), {'qrToken': 'ABC123'});
  });

  test(
    'Buổi học yêu cầu khuôn mặt: báo cần khuôn mặt, gửi lại kèm vector',
    () async {
      fakeApi((r) async {
        final body = jsonDecode(r.body) as Map;
        return body.containsKey('faceEmbedding')
            ? jsonRes({
                'status': 'present',
                'faceVerified': true,
                'checkInTime': iso(Duration.zero),
              })
            : jsonRes({'message': 'Buổi học yêu cầu xác thực khuôn mặt'}, 400);
      });
      expect(
        () => submitCheckIn('ABC123'),
        throwsA(isA<FaceRequiredException>()),
      );
      final record = await submitCheckIn('ABC123', faceEmbedding: [0.1, 0.2]);
      expect(record['faceVerified'], isTrue);
      expect(jsonDecode(requests.last.body)['faceEmbedding'], [0.1, 0.2]);
    },
  );

  test('Gửi đơn xin phép dạng multipart kèm ảnh', () async {
    fakeApi((r) async => jsonRes({'id': 'r1', 'status': 'pending'}));
    await submitAbsenceRequest(
      sessionId: 's1',
      category: 'sick',
      reason: 'Bị sốt',
      photos: [
        PickedPhoto(
          'giay-kham.jpg',
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]),
        ),
      ],
    );
    final r = requests.last;
    expect(r.url.path, '/api/absence-requests');
    expect(r.headers['content-type'], startsWith('multipart/form-data'));
    final body = latin1.decode(r.bodyBytes);
    expect(body, contains('name="sessionId"'));
    expect(body, contains('name="files"; filename="giay-kham.jpg"'));
    expect(body, contains('name="category"'));
  });

  testWidgets('Lớp của sinh viên ghép buổi học với trạng thái điểm danh', (
    tester,
  ) async {
    fakeApi((r) async {
      if (r.url.path == '/api/attendance/me') {
        return jsonRes([
          {
            'id': 'a1',
            'sessionId': 's1',
            'status': 'present',
            'method': 'qr',
            'checkInTime': iso(const Duration(days: -2)),
          },
        ]);
      }
      if (r.url.path.endsWith('/stats')) {
        return jsonRes({
          'classId': 'c1',
          'totalSessions': 2,
          'warningThresholdPercent': 20,
          'students': [],
        });
      }
      return jsonRes([
        session('s1', 'Buổi 1', const Duration(days: -2)),
        session('s2', 'Buổi 2', const Duration(days: -1)),
        session('s3', 'Buổi 3', const Duration(days: 1)),
      ]);
    });
    await tester.pumpWidget(
      app(
        const StudentClassScreen(
          classData: {
            'id': 'c1',
            'code': 'LTDD01',
            'name': 'Lập trình di động',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      requests.any((r) => r.url.queryParameters['classId'] == 'c1'),
      isTrue,
    );
    expect(find.widgetWithText(ListTile, 'Buổi 1'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Buổi 1'),
        matching: find.text('Có mặt'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Buổi 2'),
        matching: find.text('Vắng'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Buổi 3'),
        matching: find.text('Chưa điểm danh'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Buổi 3'));
    await tester.pumpAndSettle();
    expect(find.text('Xin phép vắng'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Gửi đơn'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Gửi đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập lý do'), findsOneWidget);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets(
    'Sinh viên xem đơn của mình: chỉ có nút hủy, không có nút duyệt',
    (tester) async {
      fakeApi((r) async => http.Response('', 204));
      final request = {
        'id': 'r1',
        'studentName': 'Nguyễn Văn An',
        'studentCode': 'SV001',
        'className': 'Lập trình di động',
        'sessionTitle': 'Buổi 3',
        'sessionStart': iso(const Duration(days: 1)),
        'category': 'family',
        'reason': 'Việc nhà',
        'status': 'pending',
        'evidence': [],
        'createdAt': iso(Duration.zero),
      };
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AbsenceDetailScreen(request: request, canReview: false),
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

      expect(find.text('Duyệt'), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Hủy đơn'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Hủy đơn'));
      await tester.pumpAndSettle();

      expect(requests.last.method, 'DELETE');
      expect(requests.last.url.path, '/api/absence-requests/r1');
      expect(find.text('Đã hủy đơn'), findsOneWidget);
    },
  );
}
