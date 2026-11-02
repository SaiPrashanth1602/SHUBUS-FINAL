import 'package:flutter/material.dart';

import 'app_selection/app_selection_screen.dart';

void main() => runApp(const ShubusLauncherApp());

class ShubusLauncherApp extends StatelessWidget {
  const ShubusLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHUBUS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF155EEF)),
        scaffoldBackgroundColor: const Color(0xFFF4F7FC),
      ),
      home: const AppSelectionScreen(),
    );
  }
}
