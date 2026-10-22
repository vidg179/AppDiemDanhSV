import 'package:flutter/material.dart';

import '../../widgets/home_shell.dart';
import 'absence_review_screen.dart';
import 'teacher_class_screen.dart';

class TeacherHome extends StatelessWidget {
  const TeacherHome({super.key});

  @override
  Widget build(BuildContext context) => HomeShell(
    classesTitle: 'Lớp tôi dạy',
    emptyText: 'Bạn chưa được phân công lớp nào. Liên hệ quản trị viên.',
    onClassTap: (cls) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TeacherClassScreen(classData: cls)),
    ),
    header: Card(
      child: ListTile(
        leading: const Icon(Icons.mark_email_unread_outlined),
        title: const Text('Đơn xin phép'),
        subtitle: const Text('Xem minh chứng, duyệt hoặc từ chối'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AbsenceReviewScreen()),
        ),
      ),
    ),
  );
}
