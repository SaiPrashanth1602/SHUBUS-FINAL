import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/booking_window.dart';
import '../auth/models.dart';
import '../bookings/models.dart';
import '../profile/models.dart';
import '../routes/models.dart';
import '../student_repository.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.onNavigate,
    required this.onSelectAssignment,
    required this.onLogout,
  });

  final StudentRepository repository;
  final StudentSession session;
  final Future<void> Function(int) onNavigate;
  final Future<void> Function(AfternoonAssignment) onSelectAssignment;
  final VoidCallback onLogout;

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  late Future<TransportProfile> _profileFuture;
  late Future<BookingInfo?> _bookingFuture;
  late Future<List<AfternoonAssignment>> _assignmentsFuture;
  late DateTime _bookingDate;

  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  DateTime _targetBookingDate() {
    return BookingWindow.targetBookingDate();
  }

  void _loadDashboard() {
    _bookingDate = _targetBookingDate();
    _profileFuture = _loadProfile();
    _bookingFuture = _loadBooking(_bookingDate);
    _assignmentsFuture = _loadAssignments(_bookingDate);
  }

  Future<TransportProfile> _loadProfile() {
    return widget.repository.getTransportProfile(widget.session.regNo);
  }

  Future<BookingInfo?> _loadBooking(DateTime bookingDate) {
    return widget.repository.getBooking(
      regNo: widget.session.regNo,
      date: bookingDate,
    );
  }

  Future<List<AfternoonAssignment>> _loadAssignments(
    DateTime bookingDate,
  ) async {
    return widget.repository.getAfternoonAssignments(
      regNo: widget.session.regNo,
      date: bookingDate,
    );
  }

  Future<void> _refreshDashboard() async {
    if (!mounted || _isRefreshing) return;

    _isRefreshing = true;

    setState(_loadDashboard);

    try {
      await Future.wait<dynamic>([
        _profileFuture,
        _bookingFuture,
        _assignmentsFuture,
      ]);
    } catch (_) {
      // FutureBuilder widgets render their own error/retry states.
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      } else {
        _isRefreshing = false;
      }
    }
  }

  Future<void> _selectAssignment(AfternoonAssignment assignment) async {
    await widget.onSelectAssignment(assignment);

    if (mounted) await _refreshDashboard();
  }

  void _logout() {
    widget.onLogout();
  }

  bool _isShuttle(AfternoonAssignment assignment) {
    return assignment.assignmentType.toUpperCase().contains('SHUTTLE') ||
        assignment.shuttleGroup.trim().isNotEmpty;
  }

  /// Normalizes AC values: AC, NON_AC, NON-AC, "non ac", nonac -> 'AC' / 'NON_AC'.
  String _normalizeAc(String raw) {
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('NON')) return 'NON_AC';
    if (cleaned == 'AC') return 'AC';
    return '';
  }

  /// Safety net on top of the backend filter:
  /// AC students see AC buses/shuttles (A, V, S slots),
  /// Non-AC students see Non-AC buses/shuttles (T slots).
  List<AfternoonAssignment> _filterForStudent(
    List<AfternoonAssignment> assignments,
    TransportProfile? profile,
  ) {
    final studentAc = _normalizeAc(profile?.acType ?? '');

    return assignments.where((assignment) {
      if (studentAc.isEmpty) return true;

      String required;

      if (_isShuttle(assignment)) {
        final group = assignment.shuttleGroup.trim().toUpperCase();

        if (RegExp(r'^[AVS]\d+$').hasMatch(group)) {
          required = 'AC';
        } else if (RegExp(r'^T\d+$').hasMatch(group)) {
          required = 'NON_AC';
        } else {
          required = _normalizeAc(assignment.acType);
        }
      } else {
        required = _normalizeAc(assignment.acType);
      }

      if (required.isEmpty) return true;

      return required == studentAc;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final trimmedName = widget.session.name.trim();
    final firstName = trimmedName.isEmpty
        ? 'there'
        : trimmedName.split(' ').first;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: AppColors.navy,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Text(
              'Hey, $firstName 👋',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<TransportProfile>(
              future: _profileFuture,
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const _LoadingCard(
                    label: 'Loading your morning route...',
                  );
                }

                if (profileSnapshot.hasError) {
                  return _MessageCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'Morning route unavailable',
                    message: studentErrorMessage(
                      profileSnapshot.error,
                      fallback:
                          'Could not load your transport profile. Check your connection and try again.',
                    ),
                    actionLabel: 'Retry',
                    onAction: _refreshDashboard,
                  );
                }

                final profile = profileSnapshot.data;

                if (profile == null) {
                  return _MessageCard(
                    icon: Icons.info_outline_rounded,
                    title: 'Morning route unavailable',
                    message:
                        'No transport profile was returned. Please try again.',
                    actionLabel: 'Retry',
                    onAction: _refreshDashboard,
                  );
                }

                final routeNumber = profile.morningRouteNumber.trim();
                final routeName = profile.morningRouteName.trim();

                return _MorningRouteCard(
                  routeNumber: routeNumber.isEmpty ? '—' : routeNumber,
                  routeName: routeName.isEmpty
                      ? 'Route not assigned'
                      : routeName,
                  acType: profile.acType.trim().isEmpty
                      ? 'Not specified'
                      : profile.acType,
                );
              },
            ),
            const SizedBox(height: 28),
            const _SectionHeading(title: 'AFTERNOON RIDE'),
            const SizedBox(height: 12),
            FutureBuilder<BookingInfo?>(
              future: _bookingFuture,
              builder: (context, bookingSnapshot) {
                if (bookingSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const _LoadingCard(label: 'Checking your booking...');
                }

                if (bookingSnapshot.hasError) {
                  return _MessageCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'Booking status unavailable',
                    message: studentErrorMessage(
                      bookingSnapshot.error,
                      fallback:
                          'Could not check your booking. Check your connection and try again.',
                    ),
                    actionLabel: 'Retry',
                    onAction: _refreshDashboard,
                  );
                }

                final booking = bookingSnapshot.data;

                if (booking != null) {
                  return _BookingCard(
                    booking: booking,
                    onTap: () async {
                      await widget.onNavigate(4);

                      if (mounted) await _refreshDashboard();
                    },
                  );
                }

                final closedMessage = BookingWindow.closedMessage(_bookingDate);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NoBookingCard(
                      travelDate: _bookingDate,
                      closedMessage: closedMessage,
                    ),
                    const SizedBox(height: 24),
                    FutureBuilder<TransportProfile>(
                      future: _profileFuture,
                      builder: (context, profileSnapshot) {
                        final profile = profileSnapshot.data;

                        return FutureBuilder<List<AfternoonAssignment>>(
                          future: _assignmentsFuture,
                          builder: (context, assignmentsSnapshot) {
                            if (assignmentsSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const _LoadingCard(
                                label: 'Loading available buses...',
                              );
                            }

                            if (assignmentsSnapshot.hasError) {
                              return _MessageCard(
                                icon: Icons.directions_bus_outlined,
                                title: 'Buses unavailable',
                                message: studentErrorMessage(
                                  assignmentsSnapshot.error,
                                  fallback:
                                      'Could not load eligible buses. Check your connection and try again.',
                                ),
                                actionLabel: 'Retry',
                                onAction: _refreshDashboard,
                              );
                            }

                            if (profileSnapshot.hasError) {
                              return _MessageCard(
                                icon: Icons.person_off_outlined,
                                title: 'Transport profile unavailable',
                                message: studentErrorMessage(
                                  profileSnapshot.error,
                                  fallback:
                                      'Could not load your transport profile. Check your connection and try again.',
                                ),
                                actionLabel: 'Retry',
                                onAction: _refreshDashboard,
                              );
                            }

                            final allAssignments =
                                assignmentsSnapshot.data ?? [];

                            // Nothing assigned for this date at all.
                            if (allAssignments.isEmpty) {
                              return _MessageCard(
                                icon: Icons.event_busy_outlined,
                                title: 'No buses assigned yet',
                                message:
                                    'No afternoon buses or shuttles have been assigned for '
                                    '${_formatDate(_bookingDate)} yet. '
                                    'Please check back later.',
                                actionLabel: 'Refresh',
                                onAction: _refreshDashboard,
                              );
                            }

                            final assignments = _filterForStudent(
                              allAssignments,
                              profile,
                            );

                            // Buses exist, but none match this student.
                            if (assignments.isEmpty) {
                              return const _MessageCard(
                                icon: Icons.event_busy_outlined,
                                title: 'No eligible buses right now',
                                message:
                                    'There are no afternoon buses or shuttles matching '
                                    'your AC/Non-AC type and route for this date.',
                              );
                            }

                            final regular = assignments
                                .where((a) => !_isShuttle(a))
                                .toList();

                            final shuttles = assignments
                                .where(_isShuttle)
                                .toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (closedMessage != null) ...[
                                  _ClosedBanner(
                                    message: closedMessage,
                                    travelDate: _bookingDate,
                                  ),
                                  const SizedBox(height: 18),
                                ],
                                if (regular.isNotEmpty) ...[
                                  _AssignmentSection(
                                    title: 'REGULAR ROUTES',
                                    icon: Icons.directions_bus_rounded,
                                    assignments: regular,
                                    profile: profile,
                                    travelDate: _bookingDate,
                                    onSelect: _selectAssignment,
                                  ),
                                  const SizedBox(height: 22),
                                ],
                                if (shuttles.isNotEmpty)
                                  _ShuttleDestinationSections(
                                    assignments: shuttles,
                                    profile: profile,
                                    travelDate: _bookingDate,
                                    onSelect: _selectAssignment,
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.directions_bus_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SHUBUS',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 2),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _isRefreshing ? null : _refreshDashboard,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Logout',
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 13,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _MorningRouteCard extends StatelessWidget {
  const _MorningRouteCard({
    required this.routeNumber,
    required this.routeName,
    required this.acType,
  });

  final String routeNumber;
  final String routeName;
  final String acType;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.navy, AppColors.blue],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(19),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.route_rounded, color: Colors.white, size: 25),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR MORNING ROUTE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Route $routeNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                routeName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFE0EAF8), fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                acType,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NoBookingCard extends StatelessWidget {
  const _NoBookingCard({required this.travelDate, this.closedMessage});

  final DateTime travelDate;
  final String? closedMessage;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE3E9F2)),
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.sky,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.event_seat_outlined, color: AppColors.navy),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No ride booked yet',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                closedMessage == null
                    ? 'Book for ${_formatDate(travelDate)}'
                    : '$closedMessage • ${_formatDate(travelDate)}',
                style: const TextStyle(
                  color: Color(0xFF758198),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner({required this.message, required this.travelDate});

  final String message;
  final DateTime travelDate;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E0),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFF3DFA2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.schedule_rounded, color: Color(0xFF805B12), size: 22),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF805B12),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Buses are assigned for ${_formatDate(travelDate)}, '
                'but they cannot be booked right now. '
                'Booking is open from 7:30 PM the day before until 1:45 PM on the travel day.',
                style: const TextStyle(
                  color: Color(0xFF805B12),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onTap});

  final BookingInfo booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(19),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Container(
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: const Color(0xFFBFE5D1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'BOOKING CONFIRMED',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              booking.routeName.isNotEmpty
                  ? booking.routeName
                  : 'Route ${booking.routeNumber}',
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${booking.assignmentType.isEmpty ? 'Afternoon ride' : booking.assignmentType}'
              '${booking.acType.isEmpty ? '' : ' • ${booking.acType}'}',
              style: const TextStyle(color: Color(0xFF68758A), fontSize: 13),
            ),
            const SizedBox(height: 18),
            const Divider(color: Color(0xFFE9EDF3)),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: _BookingValue(
                    label: 'TRAVEL DATE',
                    value: _formatDate(booking.bookingDate),
                  ),
                ),
                Expanded(
                  child: _BookingValue(
                    label: 'YOUR SEAT',
                    value: booking.seatNumber,
                    highlight: true,
                  ),
                ),
                Expanded(
                  child: _BookingValue(
                    label: 'BUS TYPE',
                    value: booking.acType.isEmpty ? '—' : booking.acType,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View booking details',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: AppColors.navy,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _BookingValue extends StatelessWidget {
  const _BookingValue({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF8993A5),
          fontSize: 9,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: highlight ? AppColors.navy : AppColors.text,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _ShuttleDestinationSections extends StatelessWidget {
  const _ShuttleDestinationSections({
    required this.assignments,
    required this.profile,
    required this.travelDate,
    required this.onSelect,
  });

  final List<AfternoonAssignment> assignments;
  final TransportProfile? profile;
  final DateTime travelDate;
  final Future<void> Function(AfternoonAssignment) onSelect;

  String _destination(AfternoonAssignment assignment) {
    final group = assignment.shuttleGroup.trim().toUpperCase().replaceAll(
      ' ',
      '_',
    );

    if (group == 'ALANDUR_METRO' || group.startsWith('A')) {
      return 'ALANDUR METRO';
    }

    if (group == 'VELACHERY' || group.startsWith('V')) {
      return 'VELACHERY';
    }

    if (group == 'SHOLINGANALLUR' || group.startsWith('S')) {
      return 'SHOLINGANALLUR';
    }

    if (group == 'TAMBARAM' || group.startsWith('T')) {
      return 'TAMBARAM';
    }

    return 'OTHER SHUTTLES';
  }

  /// Sorts A1, A2, ... A10 numerically (not as text).
  int _slotNumber(AfternoonAssignment assignment) {
    final match = RegExp(r'(\d+)$').firstMatch(assignment.shuttleGroup.trim());
    return match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    const destinations = [
      'ALANDUR METRO',
      'VELACHERY',
      'SHOLINGANALLUR',
      'TAMBARAM',
    ];

    final groups = <String, List<AfternoonAssignment>>{
      for (final destination in destinations)
        destination:
            (assignments.where((a) => _destination(a) == destination).toList()
              ..sort((a, b) => _slotNumber(a).compareTo(_slotNumber(b)))),
    };

    final other = assignments
        .where((a) => _destination(a) == 'OTHER SHUTTLES')
        .toList();

    if (other.isNotEmpty) {
      groups['OTHER SHUTTLES'] = other;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text(
            'SHUTTLES',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 13,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        for (final entry in groups.entries)
          if (entry.value.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 9, top: 2),
              child: Text(
                entry.key,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 12,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ...entry.value.map(
              (assignment) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AssignmentCard(
                  assignment: assignment,
                  profile: profile,
                  travelDate: travelDate,
                  onTap: () => onSelect(assignment),
                  showShuttleDestinationAsTitle: false,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _AssignmentSection extends StatelessWidget {
  const _AssignmentSection({
    required this.title,
    required this.icon,
    required this.assignments,
    required this.profile,
    required this.travelDate,
    required this.onSelect,
  });

  final String title;
  final IconData icon;
  final List<AfternoonAssignment> assignments;
  final TransportProfile? profile;
  final DateTime travelDate;
  final Future<void> Function(AfternoonAssignment) onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: AppColors.sky,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.navy, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    letterSpacing: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ...assignments.map(
        (assignment) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AssignmentCard(
            assignment: assignment,
            profile: profile,
            travelDate: travelDate,
            onTap: () => onSelect(assignment),
          ),
        ),
      ),
    ],
  );
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.profile,
    required this.travelDate,
    required this.onTap,
    this.showShuttleDestinationAsTitle = true,
  });

  final AfternoonAssignment assignment;
  final TransportProfile? profile;
  final DateTime travelDate;
  final VoidCallback onTap;
  final bool showShuttleDestinationAsTitle;

  bool get isShuttle =>
      assignment.assignmentType.toUpperCase().contains('SHUTTLE') ||
      assignment.shuttleGroup.trim().isNotEmpty;

  int get availableForStudent => assignment.availableSeatsForStudent;

  int get genderCapacity => assignment.studentGenderCapacity;

  /// Why this card is locked, or null when it is open.
  String? get lockedReason {
    if (assignment.isOpen) return null;

    final windowMessage = BookingWindow.closedMessage(travelDate);
    if (windowMessage != null) return windowMessage;

    if (isShuttle) return 'Opens after the previous shuttle is full';

    return 'Booking closed';
  }

  @override
  Widget build(BuildContext context) {
    final available = availableForStudent;
    final canSelect = assignment.isOpen && available > 0;
    final reason = lockedReason;

    return Material(
      color: canSelect ? Colors.white : const Color(0xFFF4F6F9),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: canSelect ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3E9F2)),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: isShuttle ? const Color(0xFFEAF8F0) : AppColors.sky,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isShuttle
                      ? Icons.electric_bolt_rounded
                      : Icons.directions_bus_rounded,
                  color: isShuttle ? AppColors.success : AppColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isShuttle
                          ? (showShuttleDestinationAsTitle &&
                                    assignment.shuttleGroup.trim().isNotEmpty
                                ? assignment.shuttleGroup.trim()
                                : (RegExp(r'^[AVST]\d+$').hasMatch(
                                        assignment.shuttleGroup
                                            .trim()
                                            .toUpperCase(),
                                      )
                                      ? 'Shuttle ${assignment.shuttleGroup.trim().toUpperCase()}'
                                      : (assignment.routeName.isNotEmpty
                                            ? assignment.routeName
                                            : 'Shuttle bus')))
                          : (assignment.routeName.isNotEmpty
                                ? assignment.routeName
                                : 'Route ${assignment.routeNumber}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if ((isShuttle &&
                            assignment.routeName.isNotEmpty &&
                            !(showShuttleDestinationAsTitle &&
                                assignment.shuttleGroup.trim().isNotEmpty)) ||
                        (!isShuttle && assignment.acType.isNotEmpty)) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${isShuttle && assignment.routeName.isNotEmpty ? assignment.routeName : ''}'
                        '${assignment.acType.isEmpty ? '' : '${isShuttle && assignment.routeName.isNotEmpty ? ' • ' : ''}${assignment.acType}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF758198),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    if (reason != null)
                      Text(
                        reason,
                        style: const TextStyle(
                          color: Color(0xFF805B12),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else ...[
                      Text(
                        '$available seats available for you of $genderCapacity',
                        style: TextStyle(
                          color: available > 0
                              ? AppColors.success
                              : AppColors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (available == 0) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'No seats available',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                canSelect ? Icons.chevron_right_rounded : Icons.lock_outline,
                color: canSelect ? AppColors.navy : const Color(0xFF8993A5),
                size: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFE3E9F2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LinearProgressIndicator(minHeight: 3),
        const SizedBox(height: 13),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF758198), fontSize: 12),
        ),
      ],
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFE3E9F2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.navy),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(
            color: Color(0xFF758198),
            fontSize: 12,
            height: 1.45,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: Text(actionLabel!),
            ),
          ),
        ],
      ],
    ),
  );
}

String _formatDate(DateTime? date) {
  if (date == null) return '—';

  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}
