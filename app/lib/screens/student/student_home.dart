import 'package:flutter/material.dart';

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
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScanScreen()),
          ),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Quét QR điểm danh'),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Đơn xin phép của tôi'),
            subtitle: const Text(
              'Để xin phép: vào lớp, bấm vào buổi muốn nghỉ',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyAbsenceScreen()),
            ),
          ),
        ),
      ],
    ),
  );
}
