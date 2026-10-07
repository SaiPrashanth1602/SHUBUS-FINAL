import 'package:flutter/material.dart';

import 'screens/admin_login_screen.dart';

void main() {
  runApp(const ShubusAdminApp());
}

class ShubusAdminApp extends StatelessWidget {
  const ShubusAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SHUBUS Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AdminLoginScreen(),
    );
  }
}
