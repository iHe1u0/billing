import 'package:billing/beans/user.dart';
import 'package:billing/db/payment_database.dart' show PaymentDatabase;
import 'package:billing/db/user_database.dart';
import 'package:billing/pages/add_expense.dart';
import 'package:billing/pages/add_payment.dart';
import 'package:billing/pages/home.dart';
import 'package:billing/pages/login_page.dart';
import 'package:billing/pages/payment_list.dart';
import 'package:billing/pages/register_page.dart';
import 'package:billing/pages/user_management.dart';
import 'package:billing/services/auth_service.dart';
import 'package:billing/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final user = await AuthService.getLoginUser();
  final isAutoLogin = await AuthService.isAutoLogin();
  if (isAutoLogin && user != null) {
    Session.currentUser = user; // 自动登录，设置当前用户
  } else {
    Session.currentUser = null; // 未登录或不自动登录
  }
  // Initialize database
  await UserDatabase.instance.database;
  await PaymentDatabase.instance.database;
  runApp(MainApp(initialUser: Session.currentUser));
}

class MainApp extends StatelessWidget {
  final User? initialUser;

  const MainApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', name: 'home', builder: (context, state) => const HomePage()),
        GoRoute(path: '/payment/add_payment', name: 'add_payment', builder: (context, state) => const AddPaymentPage()),
        GoRoute(path: '/payment/add_expense', name: 'add_expense', builder: (context, state) => const AddExpensePage()),
        GoRoute(
          path: '/payment/payment_list',
          name: 'payment_list',
          builder: (context, state) => const PaymentListPage(),
        ),
        GoRoute(path: '/login', name: 'login', builder: (context, state) => const LoginPage()),
        GoRoute(path: '/register', name: 'register', builder: (context, state) => const RegisterPage()),
        GoRoute(
          path: '/user_management',
          name: 'user_management',
          builder: (context, state) => const UserManagementPage(),
        ),
      ],
      initialLocation: initialUser == null ? '/login' : '/',
      redirect: (context, state) async {
        final user = await AuthService.getLoginUser();
        final isAutoLogin = await AuthService.isAutoLogin();
        final loggingIn =
            state.matchedLocation == '/login' || state.matchedLocation == '/register' || state.matchedLocation == '/';

        // 🚫 只有在自动登录开启且 user 存在的情况下，才允许继续
        if ((!isAutoLogin || user == null) && !loggingIn) {
          return '/login';
        }

        // ✅ 如果已经登录（即自动登录启用且 user 不为空），并尝试访问登录页，则跳转到首页
        if (user != null && loggingIn) {
          Session.currentUser = user;
          return '/';
        }

        return null;
      },
    );

    return MaterialApp.router(
      title: '游乐场收费软件',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'MiFont'),
      locale: const Locale('zh'),
      // 👈 默认语言设置为中文
      supportedLocales: const [
        Locale('zh'), // 中文
        // Locale('en'), // 英文（可选）
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
