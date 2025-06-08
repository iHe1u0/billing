import 'dart:convert';

import 'package:billing/services/session_service.dart';
import 'package:billing/utils/app_config.dart';
import 'package:billing/utils/file_utils.dart';
import 'package:flutter/material.dart';
import 'package:billing/db/user_database.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _password = '';
  bool _rememberMe = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final user = await UserDatabase.instance.authenticateUser(_username, _password);

      if (user != null && user.isActive) {
        final prefs = await SharedPreferences.getInstance();

        if (_rememberMe) {
          // ✅ 勾选了“记住我”才保存用户信息
          await prefs.setString(AppConfig.preferLoginUser, jsonEncode(user.toMap()));
          await prefs.setBool(AppConfig.preferAutoLogin, true);
        } else {
          // 🚫 没勾选则清除用户信息，确保不自动登录
          await prefs.remove(AppConfig.preferLoginUser);
          await prefs.setBool(AppConfig.preferAutoLogin, false);
        }

        if (mounted) {
          Session.currentUser = user;
          context.goNamed('home');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('登录失败，请检查用户名和密码')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('恢复数据'),
        actions: [
          IconButton(
            icon: Icon(Icons.restore),
            tooltip: '恢复备份的数据',
            onPressed: () async {
              FileUtils.restoreData(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: '用户名'),
                onSaved: (value) => _username = value!.trim(),
                validator: (value) => value!.isEmpty ? '请输入用户名' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: '密码'),
                obscureText: true,
                onSaved: (value) => _password = value!.trim(),
                validator: (value) => value!.isEmpty ? '请输入密码' : null,
              ),
              CheckboxListTile(
                title: const Text('记住我'),
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value!;
                  });
                },
              ),
              ElevatedButton(onPressed: _login, child: const Text('登录')),
              TextButton(
                onPressed: () {
                  context.pushNamed('register');
                },
                child: const Text('注册'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
