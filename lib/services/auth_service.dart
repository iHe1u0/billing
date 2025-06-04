import 'dart:convert';
import 'package:billing/beans/user.dart';
import 'package:billing/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _loginUserId = 'loggedInUserId';

  // 获取已登录用户
  static Future<User?> getLoginUser() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final jsonStr = prefs.getString(_loginUserId);
      if (jsonStr == null) {
        return null;
      }
      final data = jsonDecode(jsonStr);
      return User.fromMap(data);
    } catch (e) {
      debugPrint(e.toString());
    }
    return null;
  }

  // 登出
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginUserId);
    Session.currentUser = null;
  }
}
