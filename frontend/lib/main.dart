import 'package:flutter/material.dart';
import 'screens/admin_login_screen.dart';

void main() => runApp(const ShubusAdminApp());

class ShubusAdminApp extends StatelessWidget {
  const ShubusAdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SHUBUS Admin',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF155EEF)),
      scaffoldBackgroundColor: const Color(0xFFF4F7FC),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Color(0xFF12305A), elevation: 0),
    ),
    home: const AdminLoginScreen(),
  );
}
