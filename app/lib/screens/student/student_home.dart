import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/home_shell.dart';
import 'my_absence_screen.dart';
import 'scan_screen.dart';
import 'student_class_screen.dart';

class StudentHome extends StatelessWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context) => HomeShell(
    classesTitle: 'Lớp tôi học',
    emptyText: 'Bạn chưa được thêm vào lớp nào. Liên hệ giảng viên hoặc quản trị viên.',
    onClassTap: (cls) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudentClassScreen(classData: cls)),
    ),
    header: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AttendanceButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScanScreen()),
          ),
          icon: Icons.qr_code_scanner,
          label: 'Quét QR điểm danh',
        ),
        const SizedBox(height: 12),
        ShortcutCard(
          icon: Icons.description_outlined,
          title: 'Đơn xin phép của tôi',
          subtitle: 'Để xin phép: vào lớp, bấm vào buổi muốn nghỉ',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyAbsenceScreen()),
          ),
        ),
      ],
    ),
  );
}
