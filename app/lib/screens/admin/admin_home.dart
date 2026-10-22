import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'classes_screen.dart';
import 'users_screen.dart';

/// Trang quản trị: tab Lớp học và tab Người dùng.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Quản lý lớp học' : 'Quản lý người dùng'),
        actions: [
          ProfileButton(onChanged: () => setState(() {})),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [ClassesScreen(), UsersScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.class_outlined),
            selectedIcon: Icon(Icons.class_),
            label: 'Lớp học',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Người dùng',
          ),
        ],
      ),
    );
  }
}
