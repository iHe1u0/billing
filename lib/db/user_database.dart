import 'dart:io';
import 'package:billing/beans/user.dart';
import 'package:billing/utils/app_config.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class UserDatabase {
  static final UserDatabase instance = UserDatabase._init();
  static Database? _database;

  UserDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
    }
    final dbPath = await _getDatabasePath();
    final path = join(dbPath, 'users.db');

    final databaseFactory = databaseFactoryFfi;
    _database = await databaseFactory.openDatabase(path, options: OpenDatabaseOptions(version: 1, onCreate: _createDB));
    return _database!;
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

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password TEXT,
        isAdmin INTEGER,
        isActive INTEGER,
        registerTime TEXT,
        expireTime TEXT,
        note TEXT
      )
    ''');

    // 创建默认管理员
    await db.insert('users', {
      'username': AppConfig.superAdminUsername,
      'password': AppConfig.superAdminPassword,
      'isAdmin': 1,
      'isActive': 1,
      'registerTime': DateTime.now().toIso8601String(),
      'expireTime': null,
      'note': '系统超级管理员',
    });
  }

  Future<User?> authenticateUser(String username, String password) async {
    final db = await database;
    final maps = await db.query('users', where: 'username = ? AND password = ?', whereArgs: [username, password]);

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final maps = await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (maps.isNotEmpty) return User.fromMap(maps.first);
    return null;
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final maps = await db.query('users', orderBy: 'registerTime DESC');
    return maps.map((e) => User.fromMap(e)).toList();
  }

  Future<int> createUser(User user) async {
    final db = await database;

    // 插入用户
    final userId = await db.insert('users', user.toMap());

    // 创建对应的打卡表
    final tableName = 'attendance_user_$userId';
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT,
        type TEXT
      )
    ''');

    return userId;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return User.fromMap(maps.first);
    return null;
  }

  Future<Map<int, String>> getUserIdUsernameMap() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users', columns: ['id', 'username']);

    return {for (var map in maps) map['id'] as int: map['username'] as String};
  }
}
