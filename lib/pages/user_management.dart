import 'package:billing/beans/user.dart';
import 'package:flutter/material.dart';
import 'package:billing/db/user_database.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<User> _users = [];

  Future<void> _loadUsers() async {
    final users = await UserDatabase.instance.getAllUsers();
    setState(() {
      _users = users;
    });
  }

  Future<void> _toggleUserStatus(User user) async {
    final updatedUser = user.copyWith(isActive: !user.isActive);
    await UserDatabase.instance.updateUser(updatedUser);
    _loadUsers();
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('用户管理')),
      body: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return ListTile(
            title: Text(user.username),
            subtitle: Text('管理员: ${user.isAdmin ? '是' : '否'} | 状态: ${user.isActive ? '激活' : '禁用'}'),
            trailing: IconButton(
              icon: Icon(user.isActive ? Icons.lock_open : Icons.lock),
              onPressed: () => _toggleUserStatus(user),
            ),
          );
        },
      ),
    );
  }
}
