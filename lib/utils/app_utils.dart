// lib/utils/app_utils.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUtils {
  static Future<void> checkForUpdate(BuildContext context) async {
    const updateJsonUrl = 'http://192.168.0.109:10924/#s/_n76K9Ww';

    try {
      final response = await http.get(Uri.parse(updateJsonUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'];
        final downloadUrl = data['url'];
        final description = data['desc'];

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_isNewerVersion(latestVersion, currentVersion) && context.mounted) {
          _showUpdateDialog(context, latestVersion, description, downloadUrl);
        }
      } else {
        debugPrint("服务器响应错误: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("检查更新失败: $e");
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    List<int> latestParts = latest.split('.').map(int.parse).toList();
    List<int> currentParts = current.split('.').map(int.parse).toList();
    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length || latestParts[i] > currentParts[i]) {
        return true;
      } else if (latestParts[i] < currentParts[i]) {
        return false;
      }
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String version, String desc, String url) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("发现新版本 v$version"),
          content: Text(desc),
          actions: [
            TextButton(child: Text("稍后"), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: Text("立即更新"),
              onPressed: () async {
                Navigator.of(context).pop();
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("无法打开下载链接，请稍后再试。")));
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  static void showToast(
    String message, {
    Color backgroundColor = Colors.black87,
    Color textColor = Colors.white,
    ToastGravity gravity = ToastGravity.BOTTOM,
    int durationSeconds = 2,
    BuildContext? context,
  }) {
    assert(message.isNotEmpty, "消息不能为空");
    if (message.isEmpty) {
      return;
    }

    if ((Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      assert(context != null, "在桌面平台上使用showToast时，context不能为空");
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: Duration(seconds: durationSeconds),
          ),
        );
      }
    } else {
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: backgroundColor,
        textColor: textColor,
        gravity: gravity,
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: durationSeconds,
      );
    }
  }

  static Future<String?> promptPassword(BuildContext context, {bool isConfirm = false}) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: Text(isConfirm ? '请输入备份密码' : '请输入解密密码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                obscureText: true,
                decoration: InputDecoration(labelText: '密码'),
              ),
              if (isConfirm)
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: '确认密码'),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('取消')),
            TextButton(
              onPressed: () {
                final pwd = controller.text.trim();
                if (isConfirm && pwd != confirmController.text.trim()) {
                  AppUtils.showToast('两次密码不一致', context: context);
                  return;
                }
                Navigator.pop(context, pwd);
              },
              child: Text('确定'),
            ),
          ],
        );
      },
    );
  }
}
