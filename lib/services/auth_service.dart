import 'dart:convert';
import 'package:billing/beans/user.dart';
import 'package:billing/services/session_service.dart';
import 'package:billing/utils/app_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // 获取已登录用户
  static Future<User?> getLoginUser() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final jsonStr = prefs.getString(AppConfig.preferLoginUser);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr);
        return User.fromMap(data);
      }
      if (prefs.getBool(AppConfig.preferAutoLogin) == false) {
        return Session.currentUser;
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    return null;
  }

  //是否自动登录
  static Future<bool> isAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConfig.preferAutoLogin) ?? false;
  }

  // 关闭自动登录
  static Future<void> disableAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.preferAutoLogin);
    await prefs.remove(AppConfig.preferLoginUser);
  }

  // 登出
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.preferLoginUser);
    await prefs.remove(AppConfig.preferAutoLogin);
    // 清除当前用户会话
    Session.currentUser = null;
  }
}
