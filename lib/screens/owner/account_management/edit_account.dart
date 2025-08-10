import 'package:flutter/material.dart';
import 'package:ban_hang/services/manager_services/user_service.dart';

class EditAcountScreen extends StatefulWidget {
  const EditAcountScreen({super.key});

  @override
  State<EditAcountScreen> createState() => _EditAcountScreenState();
}

class _EditAcountScreenState extends State<EditAcountScreen> {
  final UserService _userService = UserService();
  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  void _fetchUsers() {
    _usersFuture = _userService.fetchEditableUsers();
  }

  Future<void> _refresh() async {
    setState(() {
      _fetchUsers();
    });
  }

  Future<bool> _showConfirmDialog(BuildContext context, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xác nhận')),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách tài khoản')),
      body: FutureBuilder(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
            return const Center(child: Text('Không có tài khoản nào.'));
          }

          final users = snapshot.data as List<Map<String, dynamic>>;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final isDeleted = user['status'] == 'đã vô hiệu hóa';

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(user['name'] ?? 'Không rõ'),
                    subtitle: Text('${user['email'] ?? ''}\nTrạng thái: ${user['status']}'),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          Navigator.pushNamed(
                            context,
                            '/update-account',
                            arguments: {
                              'userData': user,
                              'onSave': (updatedData) async {
                                await _userService.updateUser(user['id'], updatedData);
                                Navigator.pop(context); // Quay lại để gọi _refresh sau
                                await _refresh();       // Gọi lại load danh sách
                              }

                            },
                          );
                        }
                        else if (value == 'delete') {
                          final confirm = await _showConfirmDialog(context, 'Bạn có chắc muốn vô hiệu hóa tài khoản này không?');
                          if (confirm) {
                            await _userService.deleteUser(user['id']);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã vô hiệu hóa tài khoản')));
                            _refresh();
                          }
                        } else if (value == 'restore') {
                          await _userService.restoreUser(user['id']);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã khôi phục tài khoản')));
                          _refresh();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                        if (!isDeleted)
                          const PopupMenuItem(value: 'delete', child: Text('Vô hiệu hóa')),
                        if (isDeleted)
                          const PopupMenuItem(value: 'restore', child: Text('Khôi phục')),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
