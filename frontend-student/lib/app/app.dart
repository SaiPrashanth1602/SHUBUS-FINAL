import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../features/auth/models.dart';
import '../features/auth/student_login_screen.dart';
import '../features/dashboard/student_shell.dart';
import '../features/student_repository.dart';
import 'theme/app_theme.dart';

class ShubusStudentApp extends StatefulWidget {
  const ShubusStudentApp({super.key, StudentRepository? repository})
    : _repository = repository;

  final StudentRepository? _repository;

  @override
  State<ShubusStudentApp> createState() => _ShubusStudentAppState();
}

class _ShubusStudentAppState extends State<ShubusStudentApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SHUBUS Student',
      theme: buildAppTheme(),
      home: StudentAppContent(repository: widget._repository),
    );
  }
}

class StudentAppContent extends StatefulWidget {
  const StudentAppContent({super.key, this.repository});

  final StudentRepository? repository;

  @override
  State<StudentAppContent> createState() => _StudentAppContentState();
}

class _StudentAppContentState extends State<StudentAppContent> {
  late final StudentRepository repository =
      widget.repository ?? StudentRepository(ApiClient());
  StudentSession? session;

  void _setSession(StudentSession nextSession) {
    setState(() => session = nextSession);
  }

  void _logout() {
    setState(() => session = null);
  }

  @override
  Widget build(BuildContext context) {
    return session == null
        ? StudentLoginScreen(repository: repository, onSignedIn: _setSession)
        : StudentShell(
            repository: repository,
            session: session!,
            onLogout: _logout,
          );
  }
}
