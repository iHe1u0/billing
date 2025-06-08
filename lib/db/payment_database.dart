import 'package:billing/beans/payment_record.dart';
import 'package:billing/services/session_service.dart';
import 'package:billing/utils/file_utils.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path/path.dart' show join;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class PaymentDatabase {
  static final PaymentDatabase instance = PaymentDatabase._init();
  static Database? _database;

  PaymentDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('payments.db');
    return _database!;
  }

  Future<Database> _initDB(String dbName) async {
    sqfliteFfiInit();
    var databaseFactory = databaseFactoryFfi;
    final dbPath = await _getDatabasePath();
    final path = join(dbPath, dbName);
    return await databaseFactory.openDatabase(path, options: OpenDatabaseOptions(version: 1, onCreate: _createDB));
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemName TEXT,
        amount REAL,
        time TEXT,
        isRefunded INTEGER,
        isExpense INTEGER DEFAULT 0,
        userId INTEGER
      )
    ''');
  }

  Future<String> _getDatabasePath() async {
    return await FileUtils.getDatabasePath();
  }

  Future<void> addPayment(PaymentRecord record, int userId) async {
    final db = await instance.database;
    final data = record.toMap()..['userId'] = userId;
    await db.insert('payments', data);
  }

  Future<void> addExpense(PaymentRecord record, int userId) async {
    final db = await instance.database;
    final expense = PaymentRecord(
      id: record.id,
      itemName: record.itemName,
      amount: record.amount,
      time: record.time,
      isRefunded: record.isRefunded,
      isExpense: true, // 设置为支出
      userId: Session.currentUser!.id!,
    );
    final data = expense.toMap()..['userId'] = userId;
    await db.insert('payments', data);
  }

  Future<List<PaymentRecord>> fetchPayments() async {
    final db = await instance.database;
    final maps = await db.query('payments', orderBy: 'time DESC');
    return maps.map((e) => PaymentRecord.fromMap(e)).toList();
  }

  Future<void> refundPayment(int id) async {
    final db = await instance.database;
    await db.update('payments', {'isRefunded': 1, 'userId': Session.currentUser?.id}, where: 'id = ?', whereArgs: [id]);
  }

  // 获取今天的收入总额
  Future<double> getTodayIncome() async {
    final db = await instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await db.rawQuery(
      '''
    SELECT SUM(amount) as total FROM payments
    WHERE isRefunded = 0 AND isExpense = 0 AND time LIKE ?
    ''',
      ['$today%'],
    );
    return result.first['total'] == null ? 0.0 : result.first['total'] as double;
  }

  // 获取今天的支出总额
  Future<double> getTodayExpense() async {
    final db = await instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await db.rawQuery(
      '''
    SELECT SUM(amount) as total FROM payments
    WHERE isRefunded = 0 AND isExpense = 1 AND time LIKE ?
    ''',
      ['$today%'],
    );
    return result.first['total'] == null ? 0.0 : result.first['total'] as double;
  }

  // 获取今天的所有支付记录
  Future<List<PaymentRecord>> getTodayPayments() async {
    final db = await instance.database;
    final now = DateTime.now();

    final result = await db.query(
      'payments',
      where: 'date(time) = ? AND isRefunded = 0',
      whereArgs: [DateFormat('yyyy-MM-dd').format(now)],
      orderBy: 'time ASC',
    );

    return result.map((json) => PaymentRecord.fromJson(json)).toList();
  }

  // 更新记录
  Future<void> updatePayment(PaymentRecord record) async {
    final db = await instance.database;
    await db.update('payments', record.toMap(), where: 'id = ?', whereArgs: [record.id]);
  }

  /// 删除记录
  Future<void> deletePayment(int id) async {
    final db = await instance.database;
    await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  /// 查询记录
  Future<List<PaymentRecord>> queryRecords({DateTime? start, DateTime? end}) async {
    final db = await instance.database;
    String where = '';
    List<Object?> whereArgs = [];

    DateTime? adjustedStart;
    DateTime? adjustedEnd;

    if (start != null) {
      adjustedStart = DateTime(start.year, start.month, start.day - 1, 23, 59, 59, 999);
      where += 'time >= ?';
      whereArgs.add(adjustedStart.toIso8601String());
    }

    if (end != null) {
      adjustedEnd = DateTime(end.year, end.month, end.day + 1, 0, 0, 0, 0);
      if (where.isNotEmpty) where += ' AND ';
      where += 'time <= ?';
      whereArgs.add(adjustedEnd.toIso8601String());
    }

    final result = await db.query(
      'payments',
      where: where.isNotEmpty ? where : null,
      whereArgs: whereArgs,
      orderBy: 'time DESC',
    );

    return result.map((e) => PaymentRecord.fromMap(e)).toList();
  }

  /// 获取指定日期的记录
  Future<List<PaymentRecord>> getRecordsByDate(DateTime date) async {
    final db = await instance.database;
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day + 1);

    final result = await db.query(
      'payments',
      where: 'time >= ? AND time < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'time DESC',
    );

    return result.map((e) => PaymentRecord.fromMap(e)).toList();
  }

  void close() {
    _database?.close();
    _database = null;
  }
}
