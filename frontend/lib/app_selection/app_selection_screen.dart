import 'package:flutter/material.dart';

import 'package:shubus_admin_frontend/admin_app.dart';
import 'package:shubus_student_frontend/app/app.dart';
import 'package:shubus_student_frontend/app/theme/app_theme.dart';

class AppSelectionScreen extends StatelessWidget {
  const AppSelectionScreen({super.key});

  void _openStudentApp(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            Theme(data: buildAppTheme(), child: const StudentAppContent()),
      ),
    );
  }

  void _openAdminApp(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            Theme(data: buildAdminTheme(), child: const AdminAppContent()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SHUBUS')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.directions_bus_rounded,
                  size: 64,
                  color: Color(0xFF155EEF),
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose your app',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => _openStudentApp(context),
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Student App'),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _openAdminApp(context),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Admin App'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
