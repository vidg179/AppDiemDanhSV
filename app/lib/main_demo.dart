// Bản demo: chạy app với dữ liệu giả, không gọi server thật. Chỉ để xem giao diện.
// Chạy: flutter run -d chrome -t lib/main_demo.dart  rồi mở ?role=admin | teacher | student
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'core/api.dart';
import 'core/session.dart';
import 'core/ui.dart';

String _iso(Duration d) => DateTime.now().add(d).toUtc().toIso8601String();

Map<String, dynamic> _user(
  String id,
  String name,
  String role, {
  String? code,
}) => {
  'id': id,
  'username': id,
  'email': '$id@school.vn',
  'fullName': name,
  'phone': null,
  'role': role,
  'studentCode': code,
  'emailVerified': true,
  'provider': 'local',
  'hasFace': id == 'sv_an',
  'createdAt': _iso(const Duration(days: -30)),
};

final _students = [
  _user('sv_an', 'Nguyễn Văn An', 'student', code: 'SV001'),
  _user('sv_binh', 'Trần Thị Bình', 'student', code: 'SV002'),
  _user('sv_cuong', 'Lê Văn Cường', 'student', code: 'SV003'),
  _user('sv_dung', 'Phạm Thùy Dung', 'student', code: 'SV004'),
];
final _teacher = _user('gv_hoa', 'Võ Thị Hoa', 'teacher');
final _admin = _user('admin', 'Quản trị viên', 'admin');

final _classes = [
  {
    'id': 'c1',
    'code': 'LTDD01',
    'name': 'Lập trình thiết bị di động',
    'subject': 'Flutter',
    'room': 'A101',
    'teacherId': 'gv_hoa',
    'teacherName': 'Võ Thị Hoa',
    'studentCount': 42,
  },
  {
    'id': 'c2',
    'code': 'CSDL02',
    'name': 'Cơ sở dữ liệu',
    'subject': 'SQL',
    'room': 'B203',
    'teacherId': 'gv_hoa',
    'teacherName': 'Võ Thị Hoa',
    'studentCount': 38,
  },
];

List<Map<String, dynamic>> _sessions() => [
  for (final (i, off) in [(1, -14), (2, -7), (3, 0), (4, 7)])
    {
      'id': 's$i',
      'classId': 'c1',
      'title':
          'Buổi $i - ${['Giới thiệu Dart', 'Widget cơ bản', 'Quản lý state', 'Gọi API'][i - 1]}',
      'startTime': _iso(Duration(days: off, minutes: off == 0 ? -20 : 0)),
      'endTime': _iso(Duration(days: off, minutes: off == 0 ? 70 : 90)),
      'latitude': 10.8231,
      'longitude': 106.6297,
      'radiusMeters': 100,
      'requireFace': i == 3,
      'qrToken': null,
      'qrExpiresAt': null,
    },
];

List<Map<String, dynamic>> _roster() => [
  for (final (i, s) in _students.indexed)
    {
      'studentId': s['id'],
      'fullName': s['fullName'],
      'studentCode': s['studentCode'],
      'attendanceId': i < 3 ? 'a$i' : null,
      'status': ['present', 'late', 'excused', 'pending'][i],
      'method': ['qr', 'qr', 'absence-request', null][i],
      'checkInTime': i < 2 ? _iso(Duration(minutes: -15 + i * 12)) : null,
      'note': i == 2 ? 'Có phép: bị sốt' : null,
      'latitude': i < 2 ? 10.8231 + i * 0.0003 : null,
      'longitude': i < 2 ? 106.6297 + i * 0.0002 : null,
      'distanceMeters': i < 2 ? 12.0 + i * 38 : null,
      'faceVerified': i == 0,
    },
];

Map<String, dynamic> _absence(String status) => {
  'id': 'r1',
  'studentId': 'sv_cuong',
  'studentName': 'Lê Văn Cường',
  'studentCode': 'SV003',
  'classId': 'c1',
  'className': 'Lập trình thiết bị di động',
  'sessionId': 's3',
  'sessionTitle': 'Buổi 3 - Quản lý state',
  'sessionStart': _iso(const Duration(minutes: -20)),
  'category': 'sick',
  'reason': 'Em bị sốt cao, có giấy khám của bệnh viện.',
  'status': status,
  'evidence': [
    {
      'id': 'e1',
      'fileName': 'giay-kham-benh.pdf',
      'contentType': 'application/pdf',
      'size': 184320,
      'url': '/x',
    },
  ],
  'reviewerName': status == 'pending' ? null : 'Võ Thị Hoa',
  'reviewNote': null,
  'reviewedAt': null,
  'createdAt': _iso(const Duration(hours: -5)),
};

http.Response _json(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<http.Response> _handler(http.Request r) async {
  final p = r.url.path;
  if (r.method != 'GET') return _json({'ok': true});
  if (p == '/api/classes') return _json(_classes);
  if (p == '/api/users') {
    final role = r.url.queryParameters['role'];
    final all = [_admin, _teacher, ..._students];
    return _json(
      role == null ? all : all.where((u) => u['role'] == role).toList(),
    );
  }
  if (p.endsWith('/sessions')) return _json(_sessions());
  if (p.endsWith('/attendance') && p.startsWith('/api/sessions')) {
    return _json(_roster());
  }
  if (p.endsWith('/students')) return _json(_students);
  if (p == '/api/attendance/me') {
    return _json([
      {
        'id': 'a1',
        'sessionId': 's1',
        'status': 'present',
        'method': 'qr',
        'checkInTime': _iso(const Duration(days: -14)),
      },
      {
        'id': 'a2',
        'sessionId': 's2',
        'status': 'late',
        'method': 'qr',
        'checkInTime': _iso(const Duration(days: -7, minutes: 20)),
      },
    ]);
  }
  if (p.endsWith('/stats')) {
    return _json({
      'classId': 'c1',
      'totalSessions': 5,
      'warningThresholdPercent': 20,
      'students': [
        for (final (i, s) in _students.indexed)
          {
            'studentId': s['id'],
            'fullName': s['fullName'],
            'studentCode': s['studentCode'],
            'present': [5, 3, 2, 4][i],
            'late': [0, 1, 0, 1][i],
            'excused': [0, 0, 1, 0][i],
            'absent': [0, 1, 2, 0][i],
            'absentPercent': [0, 20, 40, 0][i],
            'warning': i > 0 && i < 3,
          },
      ],
    });
  }
  if (p == '/api/absence-requests') {
    return _json([
      _absence('pending'),
      {
        ..._absence('approved'),
        'id': 'r2',
        'sessionTitle': 'Buổi 2 - Widget cơ bản',
      },
    ]);
  }
  if (p.startsWith('/api/absence-requests/')) return _json(_absence('pending'));
  if (p == '/api/users/me') return _json(Session.user ?? _student);
  return _json({});
}

final _student = _students.first;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Api.client = MockClient(_handler);
  Api.token = 'demo';
  final role = Uri.base.queryParameters['role'] ?? 'student';
  Session.user = switch (role) {
    'admin' => _admin,
    'teacher' => _teacher,
    _ => _student,
  };
  runApp(
    MaterialApp(
      title: 'Điểm danh HUTECH (demo)',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: homeFor(role),
    ),
  );
}
