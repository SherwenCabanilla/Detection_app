import 'package:flutter/material.dart';
import 'user/login_page.dart';
import 'user/home_page.dart';
import 'user/register_page.dart';
import 'expert/expert_dashboard.dart';
import 'test_account.dart';
import 'admin/screens/admin_login.dart';

void main() {
  runApp(const CapstoneApp());
}

class CapstoneApp extends StatelessWidget {
  const CapstoneApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mango Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue,
          ),
        ),
      ),
      home: const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/user-home': (context) => const HomePage(),
        '/expert-home': (context) => const ExpertDashboard(),
        '/admin-login': (context) => const AdminLogin(),
      },
    );
  }
}
