
import 'package:billing/db/payment_database.dart' show PaymentDatabase;
import 'package:billing/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
      locale: const Locale('zh'), // 👈 默认语言设置为中文
      supportedLocales: const [
        Locale('zh'), // 中文
        Locale('en'), // 英文（可选）
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
