import 'package:billing/db/user_database.dart';
import 'package:flutter/material.dart';
import 'package:billing/beans/user.dart';
import 'package:intl/intl.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<User> _users = [];
  User? _selectedUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await UserDatabase.instance.getAllUsers();
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _handleAttendance() async {
    if (_selectedUser == null) return;

    final db = await UserDatabase.instance.database;
    final tableName = 'attendance_user_${_selectedUser!.id}';

    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timestamp = now.toIso8601String();

    // 查询当天所有打卡记录
    final result = await db.query(
      tableName,
      where: "timestamp LIKE ?",
      whereArgs: ['$dateStr%'],
      orderBy: "timestamp ASC",
    );

    final existingClockIn = result.where((r) => r['type'] == '上班').toList();
    final existingClockOut = result.where((r) => r['type'] == '下班').toList();

    String message;

    if (existingClockIn.isEmpty) {
      // 没有上班记录，插入上班
      await db.insert(tableName, {'timestamp': timestamp, 'type': '上班'});
      message = '上班打卡成功';
    } else if (existingClockOut.isEmpty) {
      // 有上班无下班，插入下班
      await db.insert(tableName, {'timestamp': timestamp, 'type': '下班'});
      message = '下班打卡成功';
    } else {
      // 上班和下班都存在，判断是否更新“下班”时间
      final existClockOutString = existingClockOut.first['timestamp'] as String?;
      if (existClockOutString == null) {
        return;
      }
      final oldOutTime = DateTime.parse(existClockOutString);
      if (now.isAfter(oldOutTime)) {
        await db.update(
          tableName,
          {'timestamp': timestamp},
          where: 'id = ?',
          whereArgs: [existingClockOut.first['id']],
        );
        message = '下班打卡已更新为更晚时间';
      } else {
        message = '已有下班打卡记录，当前时间比已打卡时间早，不进行更新';
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selectedUser!.username}：$message\n时间：${DateFormat('HH:mm:ss').format(now)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("打卡页面")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<User>(
                    value: _selectedUser,
                    hint: const Text("请选择用户"),
                    items: _users
                        .where((user) => (user.id != 1 || user.username != 'admin')) // 过滤掉 admin 用户
                        .map((user) {
                          return DropdownMenuItem<User>(value: user, child: Text(user.username));
                        })
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedUser = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _handleAttendance, child: const Text("打卡")),
                ],
              ),
            ),
    );
  }
}
