import 'package:billing/db/user_database.dart';
import 'package:billing/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:billing/beans/user.dart';
import 'package:table_calendar/table_calendar.dart';

class AttendanceSummaryPage extends StatefulWidget {
  const AttendanceSummaryPage({super.key});

  @override
  State<AttendanceSummaryPage> createState() => _AttendanceSummaryPageState();
}

class _AttendanceSummaryPageState extends State<AttendanceSummaryPage> {
  List<User> _users = [];
  User? _selectedUser;
  Map<String, List<String>> _dailyTypes = {};
  bool _isLoading = true;
  int _days = 7;
  Map<String, List<Map<String, dynamic>>> _detailedRecords = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    List<User> users = [];
    if (Session.currentUser != null) {
      User currentUser = Session.currentUser!;
      if (currentUser.isAdmin) {
        users = await UserDatabase.instance.getAllUsers();
      } else {
        users.add(currentUser);
      }
    }
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _calculateSummary() async {
    if (_selectedUser == null) return;

    final db = await UserDatabase.instance.database;
    final tableName = 'attendance_user_${_selectedUser!.id}';
    final today = DateTime.now();
    final startDate = today.subtract(Duration(days: _days - 1));
    final allRecords = await db.query(tableName, where: "timestamp >= ?", whereArgs: [startDate.toIso8601String()]);
    final Map<String, List<Map<String, dynamic>>> detailed = {};
    final Map<String, List<String>> daily = {};

    for (final record in allRecords) {
      final ts = DateTime.parse(record['timestamp'] as String);
      final type = record['type'] as String;
      final day = DateFormat('yyyy-MM-dd').format(ts);
      daily.putIfAbsent(day, () => []).add(type);

      daily.putIfAbsent(day, () => []).add(type);
      detailed.putIfAbsent(day, () => []).add({'type': type, 'timestamp': ts, 'id': record['id']});
    }
    setState(() {
      _dailyTypes = daily;
      _detailedRecords = detailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    int attended = _dailyTypes.entries.where((e) => e.value.contains('上班') && e.value.contains('下班')).length;
    int partial = _dailyTypes.entries.where((e) => e.value.length == 1).length;
    int absent = _days - _dailyTypes.length;

    return Scaffold(
      appBar: AppBar(title: const Text("考勤统计")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<User>(
                    hint: const Text("选择用户"),
                    value: _selectedUser,
                    items: _users.map((u) => DropdownMenuItem(value: u, child: Text(u.username))).toList(),
                    onChanged: (u) {
                      setState(() {
                        _selectedUser = u;
                        _dailyTypes.clear();
                      });
                      _calculateSummary();
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text("统计天数："),
                      DropdownButton<int>(
                        value: _days,
                        items: const [7, 30].map((d) => DropdownMenuItem(value: d, child: Text("$d天"))).toList(),
                        onChanged: (d) {
                          setState(() => _days = d!);
                          _calculateSummary();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_selectedUser != null)
                    Expanded(
                      child: ListView(
                        children: [
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _buildStatRow("✅ 完整打卡天数", attended),
                                  _buildStatRow("⚠️ 部分打卡（缺上下其中一个）", partial),
                                  _buildStatRow("❌ 缺勤天数", absent),
                                  const Divider(),
                                  _buildStatRow(
                                    "📊 出勤率",
                                    "${((attended + partial) / _days * 100).toStringAsFixed(1)}%",
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildCalendar(),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildCalendar() {
    // final startDate = DateTime.now().subtract(Duration(days: _days - 1));
    final startDate = DateTime.utc(2025, 01, 01);
    final endDate = DateTime.now();

    return TableCalendar(
      firstDay: startDate,
      lastDay: endDate,
      focusedDay: endDate,
      calendarFormat: CalendarFormat.month,
      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
      locale: 'zh_CN',
      calendarStyle: CalendarStyle(
        defaultTextStyle: const TextStyle(color: Colors.black),
        outsideDaysVisible: true,
        markersAlignment: Alignment.bottomCenter,
        todayDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final key = DateFormat('yyyy-MM-dd').format(day);
          Color? bgColor;
          if (_dailyTypes.containsKey(key)) {
            final types = _dailyTypes[key]!;
            if (types.contains('上班') && types.contains('下班')) {
              // bgColor = Colors.green;
            } else {
              bgColor = Colors.yellow;
            }
          } else {
            bgColor = Colors.red;
          }
          return GestureDetector(
            onTap: () => _showDayDialog(key),
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('${day.day}', style: const TextStyle(color: Colors.black)),
            ),
          );
        },
      ),
      onDaySelected: (selectedDay, focusedDay) {
        final key = DateFormat('yyyy-MM-dd').format(selectedDay);
        _showDayDialog(key);
      },
    );
  }

  void _showDayDialog(String dateKey) {
    final records = _detailedRecords[dateKey] ?? [];
    // 判断已有的打卡类型
    final existingTypes = records.map((r) => r['type'] as String).toSet();
    final missingTypes = ['上班', '下班'].where((t) => !existingTypes.contains(t)).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("打卡详情 - $dateKey"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (records.isNotEmpty)
              ...records.map((record) {
                final DateTime ts = record['timestamp'];
                final String type = record['type'];
                final int id = record['id'];

                return ListTile(
                  title: Text('$type - ${DateFormat('HH:mm').format(ts)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDeleteRecord(id, dateKey),
                  ),
                  onTap: () async {
                    final TimeOfDay? newTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(ts),
                    );
                    if (newTime != null) {
                      final newDateTime = DateTime(ts.year, ts.month, ts.day, newTime.hour, newTime.minute);

                      final db = await UserDatabase.instance.database;
                      final tableName = 'attendance_user_${_selectedUser!.id}';
                      await db.update(
                        tableName,
                        {'timestamp': newDateTime.toIso8601String()},
                        where: 'id = ?',
                        whereArgs: [id],
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                      await _calculateSummary();
                      _showDayDialog(dateKey);
                    }
                  },
                );
              })
            else
              const Text("未打卡"),
            const SizedBox(height: 10),
            if (missingTypes.isNotEmpty)
              ...missingTypes.map(
                (type) => ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text("补卡：$type"),
                  onPressed: () => _showMakeUpDialog(dateKey, type),
                ),
              ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("关闭"))],
      ),
    );
  }

  void _showMakeUpDialog(String dateKey, String type) async {
    if (Session.currentUser?.isAdmin == false) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("只有管理员可以补卡")));
      return;
    }

    final date = DateTime.parse('$dateKey 00:00:00');
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));

    if (picked != null) {
      final timestamp = DateTime(date.year, date.month, date.day, picked.hour, picked.minute);
      final db = await UserDatabase.instance.database;
      final tableName = 'attendance_user_${_selectedUser!.id}';

      await db.insert(tableName, {'timestamp': timestamp.toIso8601String(), 'type': type});
      if (mounted) {
        Navigator.pop(context); // 关闭补卡对话框
      }
      await _calculateSummary();
      _showDayDialog(dateKey); // 刷新弹窗
    }
  }

  void _confirmDeleteRecord(int id, String dateKey) {
    if (Session.currentUser?.isAdmin == false) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("只有管理员可以删除打卡记录")));
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("确认删除"),
        content: const Text("确定要删除这条打卡记录吗？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          TextButton(
            onPressed: () async {
              final db = await UserDatabase.instance.database;
              final tableName = 'attendance_user_${_selectedUser!.id}';
              await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
              if (context.mounted) {
                Navigator.pop(context); // 关闭确认框
                Navigator.pop(context); // 关闭打卡详情框
              }
              await _calculateSummary(); // 刷新
              _showDayDialog(dateKey); // 重新打开打卡详情
            },
            child: const Text("删除", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value.toString())]),
    );
  }
}
