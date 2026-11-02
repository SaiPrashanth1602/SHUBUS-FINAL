import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../auth/models.dart';
import '../bookings/bookings_screen.dart';
import '../profile/profile_screen.dart';
import '../routes/routes_screen.dart';
import '../seat_selection/seat_selection_screen.dart';
import '../routes/models.dart';
import '../student_repository.dart';
import 'student_dashboard_screen.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({
    super.key,
    required this.repository,
    required this.session,
    required this.onLogout,
  });

  final StudentRepository repository;
  final StudentSession session;
  final VoidCallback onLogout;

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  Future<void> _openSelectedAssignment(AfternoonAssignment assignment) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.navy,
            title: const Text(
              'Choose a Seat',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          body: SeatSelectionScreen(
            repository: widget.repository,
            session: widget.session,
            initialAssignmentId: assignment.assignmentId,
          ),
        ),
      ),
    );
  }

  Future<void> _openScreen(int index) async {
    late final Widget screen;
    late final String title;

    switch (index) {
      case 1:
        title = 'My Profile';
        screen = ProfileScreen(
          repository: widget.repository,
          session: widget.session,
        );
        break;
      case 2:
        title = 'Explore Routes';
        screen = RoutesScreen(
          repository: widget.repository,
          session: widget.session,
        );
        break;
      case 3:
        title = 'Book a Seat';
        screen = SeatSelectionScreen(
          repository: widget.repository,
          session: widget.session,
        );
        break;
      case 4:
        title = 'My Bookings';
        screen = BookingsScreen(
          repository: widget.repository,
          session: widget.session,
        );
        break;
      default:
        return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => index == 3
            ? Scaffold(
                backgroundColor: AppColors.background,
                appBar: AppBar(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.navy,
                  title: const Text(
                    'Book a Seat',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                body: screen,
              )
            : _PageFrame(title: title, child: screen),
      ),
    );
  }

  Future<void> _navigate(int index) async {
    await _openScreen(index);
  }

  Future<void> _selectAssignment(AfternoonAssignment assignment) async {
    await _openSelectedAssignment(assignment);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StudentDashboardScreen(
        repository: widget.repository,
        session: widget.session,
        onNavigate: _navigate,
        onSelectAssignment: _selectAssignment,
        onLogout: widget.onLogout,
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: child,
    );
  }
}
