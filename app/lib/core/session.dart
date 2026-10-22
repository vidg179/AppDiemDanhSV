import 'package:flutter/widgets.dart';

import '../screens/admin/admin_home.dart';
import '../screens/student/student_home.dart';
import '../screens/teacher/teacher_home.dart';
import 'api.dart';

class Session {
  static Map<String, dynamic>? user;

  static String get role => user?['role'] ?? '';
  static String get userId => user?['id'] ?? '';
  static String get fullName => user?['fullName'] ?? '';

  static Future<void> signIn(Map<String, dynamic> auth) async {
    await Api.saveToken(auth['token']);
    user = Map<String, dynamic>.from(auth['user']);
  }

  static Future<void> refresh() async {
    user = Map<String, dynamic>.from(await Api.get('/api/users/me'));
  }

  static Future<void> signOut() async {
    await Api.saveToken(null);
    user = null;
  }
}

/// Phân quyền: mỗi vai trò vào một trang chủ riêng.
Widget homeFor(String role) => switch (role) {
  'admin' => const AdminHome(),
  'teacher' => const TeacherHome(),
  _ => const StudentHome(),
};
