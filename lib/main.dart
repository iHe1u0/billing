import 'package:billing/db/payment_database.dart' show PaymentDatabase;
import 'package:billing/pages/add_expense.dart';
import 'package:billing/pages/add_payment.dart';
import 'package:billing/pages/home.dart';
import 'package:billing/pages/payment_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final _ = await PaymentDatabase.instance.database;
  runApp(MainApp());
}

// ignore: unused_element
final _router = GoRouter(
  routes: [
    GoRoute(path: '/', name: 'home', builder: (context, state) => const HomePage()),
    GoRoute(path: '/payment/add_payment', name: 'add_payment', builder: (context, state) => const AddPaymentPage()),
    GoRoute(path: '/payment/add_expense', name: 'add_expense', builder: (context, state) => const AddExpensePage()),
    GoRoute(path: '/payment/payment_list', name: 'payment_list', builder: (context, state) => const PaymentListPage()),
  ],
);

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '游乐场收费软件',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'MiFont'),
      locale: const Locale('zh'), // 👈 默认语言设置为中文
      supportedLocales: const [
        Locale('zh'), // 中文
        // Locale('en'), // 英文（可选）
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
