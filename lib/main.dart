import 'package:billing/db/payment_database.dart' show PaymentDatabase;
import 'package:billing/pages/home.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final _ = await PaymentDatabase.instance.database;
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '游乐场收费软件',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'MiFont'),
      home: HomePage(),
    );
  }
}
