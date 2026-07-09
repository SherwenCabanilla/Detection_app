import 'package:flutter/material.dart';
import '../ui/screens/auth/login_page.dart';

class Routes {
  static void navigateToLogin(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }
}
