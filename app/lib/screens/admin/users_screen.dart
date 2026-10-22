import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/ui.dart';
import '../../widgets/common.dart';
import 'user_form_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const _filters = <(String?, String)>[
    (null, 'Tất cả'),
    ('admin', 'Quản trị'),
    ('teacher', 'Giảng viên'),
    ('student', 'Sinh viên'),
  ];

  final _search = TextEditingController();
  String? _role;
  Timer? _debounce;
  late Future<List<dynamic>> _users = _load();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _load() async {
    final query = {
      'role': ?_role,
      if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
    };
    final qs = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    return await Api.get('/api/users$qs') as List<dynamic>;
  }

  Future<void> _reload() async {
    setState(() {
      _users = _load();
    });
    await _users;
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _openForm([Map<String, dynamic>? user]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => UserFormScreen(user: user)),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    final ok = await confirm(
      context,
      title: 'Xóa ${user['fullName']}?',
      message: 'Tài khoản cùng dữ liệu điểm danh và đơn xin phép của người này sẽ bị xóa vĩnh viễn.',
    );
    if (!ok) return;
    try {
      await Api.delete('/api/users/${user['id']}');
      if (mounted) {
        showMessage(context, 'Đã xóa ${user['fullName']}', error: false);
      }
      _reload();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Thêm người dùng'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên, tên đăng nhập, email, mã SV',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final (value, label) in _filters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _role == value,
                      onSelected: (_) {
                        _role = value;
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncListView(
              future: _users,
              onRefresh: _reload,
              emptyIcon: Icons.person_search,
              emptyText: 'Không có người dùng nào khớp.',
              itemBuilder: (context, u) => _UserTile(
                user: u,
                onEdit: () => _openForm(u),
                onDelete: u['id'] == Session.userId ? null : () => _delete(u),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onEdit, this.onDelete});

  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final details = [
      '@${user['username']}',
      if (user['studentCode'] != null) user['studentCode'],
      user['email'],
    ].join(' · ');
    return ListTile(
      onTap: onEdit,
      leading: CircleAvatar(child: Text(initials(user['fullName']))),
      title: Row(
        children: [
          Flexible(
            child: Text(user['fullName'], overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          RoleChip(user['role']),
        ],
      ),
      subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: PopupMenuButton<String>(
        tooltip: 'Thao tác',
        onSelected: (v) => v == 'edit' ? onEdit() : onDelete?.call(),
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(leading: Icon(Icons.edit), title: Text('Sửa')),
          ),
          if (onDelete != null)
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('Xóa'),
              ),
            ),
        ],
      ),
    );
  }
}
