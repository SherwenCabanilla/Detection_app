import 'package:flutter/material.dart';
import 'user/login_page.dart';
import 'user/home_page.dart';
import 'user/register_page.dart';
import 'expert/expert_dashboard.dart';
import 'test_account.dart';
import 'admin/screens/admin_login.dart';

void main() {
  runApp(CapstoneApp());
}

class CapstoneApp extends StatelessWidget {
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
      home: LoginPage(),
      routes: {
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/user-home': (context) => HomePage(),
        '/expert-home': (context) => ExpertDashboard(),
        '/admin-login': (context) => AdminLogin(),
      },
    );
  }
}
