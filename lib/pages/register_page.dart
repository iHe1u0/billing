import 'package:billing/beans/user.dart';
import 'package:flutter/material.dart';
import 'package:billing/db/user_database.dart';
import 'package:go_router/go_router.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _password = '';
  String _note = '';

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final existingUser = await UserDatabase.instance.getUserByUsername(_username);
      if (existingUser != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('用户名已存在，请选择其他用户名')));
        }
        return;
      }
      final newUser = User(
        username: _username,
        password: _password,
        isAdmin: false,
        isActive: true,
        registerTime: DateTime.now(),
        expireTime: null,
        note: _note,
      );
      await UserDatabase.instance.createUser(newUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('注册成功，请登录')));
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
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
              TextFormField(
                decoration: const InputDecoration(labelText: '备注'),
                onSaved: (value) => _note = value!.trim(),
              ),
              ElevatedButton(onPressed: _register, child: const Text('注册')),
            ],
          ),
        ),
      ),
    );
  }
}
