import 'package:flutter/material.dart';

import 'screens/admin_login_screen.dart';

class ShubusAdminApp extends StatelessWidget {
  const ShubusAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHUBUS Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      home: const AdminAppContent(),
    );
  }
}

class AdminAppContent extends StatelessWidget {
  const AdminAppContent({super.key});

  @override
  Widget build(BuildContext context) => const AdminLoginScreen();
}

ThemeData buildAdminTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF155EEF)),
    scaffoldBackgroundColor: const Color(0xFFF4F7FC),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF12305A),
      elevation: 0,
    ),
  );
}
