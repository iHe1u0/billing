// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'package:billing/db/payment_database.dart';
import 'package:billing/db/user_database.dart';
import 'package:billing/utils/app_utils.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

class FileUtils {
  static Future<Directory?> getSaveDirectory() async {
    // 请求权限
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.storage.request();
      if (!status.isGranted) return null;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // 桌面系统通过文件选择器选择文件夹
      final path = await FilePicker.platform.getDirectoryPath();
      return path != null ? Directory(path) : null;
    } else if (Platform.isAndroid) {
      // Android 10 及以上需使用 getExternalStorageDirectory 或 getExternalStorageDirectories
      try {
        final dir = await getExternalStorageDirectory();
        if (dir != null && await dir.exists()) {
          return dir;
        }
      } catch (e) {
        AppUtils.showToast("获取 Android 存储目录失败: $e");
      }
    } else if (Platform.isIOS) {
      // iOS 可使用应用的 Documents 目录
      try {
        final dir = await getApplicationDocumentsDirectory();
        if (await dir.exists()) {
          return dir;
        }
      } catch (e) {
        AppUtils.showToast("获取 iOS 文档目录失败: $e");
      }
    }

    return null;
  }

  static Future<String> getDatabasePath() async {
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

  static Future<bool> backupData(BuildContext context) async {
    try {
      final dataDir = await getDatabasePath();
      final dbDir = Directory(dataDir);
      if (!await dbDir.exists()) {
        AppUtils.showToast('数据库目录不存在', context: context);
        return false;
      }

      final output = await FilePicker.platform.saveFile(
        dialogTitle: '保存加密备份文件',
        fileName: 'database_backup.enc',
        type: FileType.custom,
        allowedExtensions: ['enc'],
      );

      if (output == null) return false;

      final archive = Archive();
      for (final file in dbDir.listSync(recursive: true)) {
        if (file is File) {
          final relativePath = p.relative(file.path, from: dbDir.path);
          archive.addFile(ArchiveFile(relativePath, file.lengthSync(), file.readAsBytesSync()));
        }
      }

      final zipData = ZipEncoder().encode(archive)!;

      // 🔐 用户输入密码
      final password = await AppUtils.promptPassword(context, isConfirm: true);
      if (password == null || password.isEmpty) return false;

      final encryptedData = aesEncrypt(zipData, password);
      await File(output).writeAsBytes(encryptedData);

      AppUtils.showToast('备份成功: $output', context: context);
      return true;
    } catch (e) {
      AppUtils.showToast('备份失败: $e', context: context);
      return false;
    }
  }

  static Future<bool> restoreData(BuildContext context) async {
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['enc']);

      if (picked == null || picked.files.isEmpty) return false;
      final file = File(picked.files.single.path!);

      // 🔐 用户输入密码
      final password = await AppUtils.promptPassword(context);
      if (password == null || password.isEmpty) return false;

      final encryptedBytes = file.readAsBytesSync();
      final decryptedBytes = aesDecrypt(encryptedBytes, password);

      final archive = ZipDecoder().decodeBytes(decryptedBytes);
      final dataDir = await getDatabasePath();

      _closeDatabase();

      for (final file in archive) {
        final filePath = p.join(dataDir, file.name);
        final outputFile = File(filePath);

        if (outputFile.existsSync()) {
          final overwrite = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('覆盖确认'),
              content: Text('文件 ${file.name} 已存在，是否覆盖？'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('否')),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('是')),
              ],
            ),
          );
          if (overwrite != true) continue;
        }

        if (file.isFile) {
          File(filePath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(filePath).createSync(recursive: true);
        }
      }

      AppUtils.showToast('恢复成功', context: context);
      return true;
    } catch (e) {
      AppUtils.showToast('恢复失败: $e', context: context);
      debugPrint('恢复失败: $e');
      return false;
    }
  }

  static void _closeDatabase() {
    UserDatabase.instance.close();
    PaymentDatabase.instance.close();
  }

  static List<int> aesEncrypt(List<int> data, String password) {
    final key = encrypt.Key.fromUtf8(password.padRight(32, '0').substring(0, 32));
    final iv = encrypt.IV.fromSecureRandom(16); // 🔐 随机 IV
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encryptBytes(data, iv: iv);

    // 保存 IV + 加密数据
    return iv.bytes + encrypted.bytes;
  }

  static List<int> aesDecrypt(List<int> encryptedData, String password) {
    final key = encrypt.Key.fromUtf8(password.padRight(32, '0').substring(0, 32));
    final ivBytes = encryptedData.sublist(0, 16);
    final encryptedBytes = encryptedData.sublist(16);

    final iv = encrypt.IV(Uint8List.fromList(ivBytes));
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypt.Encrypted(Uint8List.fromList(encryptedBytes));
    return encrypter.decryptBytes(encrypted, iv: iv);
  }
}
