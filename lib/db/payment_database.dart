import 'dart:io';

import 'package:billing/beans/payment_record.dart';
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
    if (Platform.isWindows || Platform.isLinux) {
      // Use FFI for Windows and Linux
      sqfliteFfiInit();
    }
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
        isExpense INTEGER DEFAULT 0
      )
    ''');
  }

  Future<String> _getDatabasePath() async {
    String dbPath;

    if (Platform.isWindows || Platform.isLinux) {
      // 可执行文件所在的目录
      final executableDir = Directory.current.path;
      final dataDir = join(executableDir, 'data');

      // 如果data目录不存在，则创建
      await Directory(dataDir).create(recursive: true);

      dbPath = join(dataDir, "database");
    } else {
      // 其他平台使用默认数据库路径
      final defaultDbPath = await databaseFactory.getDatabasesPath();
      dbPath = defaultDbPath;
    }

    return dbPath;
  }

  Future<void> addPayment(PaymentRecord record) async {
    final db = await instance.database;
    await db.insert('payments', record.toMap());
  }

  Future<void> addExpense(PaymentRecord record) async {
    final db = await instance.database;
    final expense = PaymentRecord(
      id: record.id,
      itemName: record.itemName,
      amount: record.amount,
      time: record.time,
      isRefunded: record.isRefunded,
      isExpense: true, // 设置为支出
    );
    await db.insert('payments', expense.toMap());
  }

  Future<List<PaymentRecord>> fetchPayments() async {
    final db = await instance.database;
    final maps = await db.query('payments', orderBy: 'time DESC');
    return maps.map((e) => PaymentRecord.fromMap(e)).toList();
  }

  Future<void> refundPayment(int id) async {
    final db = await instance.database;
    await db.update('payments', {'isRefunded': 1}, where: 'id = ?', whereArgs: [id]);
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
}
