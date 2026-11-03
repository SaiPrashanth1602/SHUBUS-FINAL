import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/booking_window.dart';
import '../../core/widgets/status_views.dart';
import '../auth/models.dart';
import '../bookings/models.dart';
import '../routes/models.dart';
import '../student_repository.dart';
import 'seat_layout.dart';
import 'booked_seat_map.dart';

class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({
    super.key,
    required this.repository,
    required this.session,
    this.initialAssignmentId,
  });

  final StudentRepository repository;
  final StudentSession session;
  final int? initialAssignmentId;

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  late DateTime _date;

  late Future<List<AfternoonAssignment>> _assignmentsFuture;

  AfternoonAssignment? _selectedAssignment;
  SeatPosition? _selectedSeat;

  List<Map<String, dynamic>> _seats = [];

  bool _loadingSeats = false;
  bool _bookingInProgress = false;

  BookingInfo? _existingBooking;
  bool _initialAssignmentHandled = false;

  @override
  void initState() {
    super.initState();
    _date = _targetBookingDate();
    _assignmentsFuture = _loadAssignments();
  }

  DateTime _targetBookingDate() {
    return BookingWindow.targetBookingDate();
  }

  Future<List<AfternoonAssignment>> _loadAssignments() {
    return widget.repository.getAfternoonAssignments(
      regNo: widget.session.regNo,
      date: _date,
    );
  }

  void _refreshAssignments() {
    final future = _loadAssignments();
    setState(() {
      _assignmentsFuture = future;
    });
  }

  String _displayDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _weekday(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[date.weekday - 1];
  }

  Future<void> _selectAssignment(AfternoonAssignment? assignment) async {
    if (assignment == null || _bookingInProgress) return;

    setState(() {
      _selectedAssignment = assignment;
      _selectedSeat = null;
      _seats = [];
      _existingBooking = null;
      _loadingSeats = true;
    });

    try {
      final results = await Future.wait<dynamic>([
        widget.repository.getSeats(
          regNo: widget.session.regNo,
          assignmentId: assignment.assignmentId,
          date: _date,
        ),
        widget.repository.getBooking(regNo: widget.session.regNo, date: _date),
      ]);

      if (!mounted ||
          _selectedAssignment?.assignmentId != assignment.assignmentId) {
        return;
      }

      setState(() {
        _seats = results[0] as List<Map<String, dynamic>>;
        _existingBooking = results[1] as BookingInfo?;
        _loadingSeats = false;
      });
    } catch (error) {
      if (!mounted ||
          _selectedAssignment?.assignmentId != assignment.assignmentId) {
        return;
      }

      if (error is AppException && error.statusCode == 409) {
        _returnToDashboardForRefresh(
          message: studentErrorMessage(
            error,
            fallback: 'This bus is no longer available for booking.',
          ),
        );
        return;
      }

      setState(() {
        _loadingSeats = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load seat availability. '
            '${studentErrorMessage(error, fallback: 'Please try again.')}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _seatStatus(SeatPosition position) {
    for (final seat in _seats) {
      if ((seat['seatNumber'] ?? '').toString() == position.label) {
        return (seat['status'] ?? 'UNKNOWN').toString().toUpperCase();
      }
    }

    return 'UNKNOWN';
  }

  SeatState _stateFor(SeatPosition position) {
    final status = _seatStatus(position);

    if (status == 'FACULTY') {
      return SeatState.facultyRestricted;
    }

    if (status == 'GENDER_RESTRICTED' || status == 'RESTRICTED') {
      return SeatState.genderRestricted;
    }

    if (status == 'BOOKED' || status == 'OCCUPIED' || status == 'RESERVED') {
      return SeatState.booked;
    }

    if (_selectedSeat?.label == position.label) {
      return SeatState.selected;
    }

    return SeatState.available;
  }

  bool _isSeatAvailable(SeatPosition position) {
    return _seatStatus(position) == 'AVAILABLE';
  }

  Set<String> get _bookedSeatLabels => {
    for (final seat in _seats)
      if ((seat['status'] ?? '').toString().toUpperCase() == 'BOOKED')
        (seat['seatNumber'] ?? '').toString(),
  };

  int get _availableSeatCount {
    return _seats.where((seat) {
      return (seat['status'] ?? '').toString().toUpperCase() == 'AVAILABLE';
    }).length;
  }

  Future<void> _confirmBooking() async {
    final assignment = _selectedAssignment;
    final seat = _selectedSeat;

    if (assignment == null || seat == null || _bookingInProgress) {
      return;
    }

    if (_existingBooking != null) {
      _showMessage('You already have a booking for this date.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.confirmation_number_outlined),
              SizedBox(width: 10),
              Expanded(child: Text('Confirm booking')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConfirmationRow(
                label: 'Route',
                value: '${assignment.routeNumber} - ${assignment.routeName}',
              ),
              const SizedBox(height: 12),
              _ConfirmationRow(
                label: 'Travel date',
                value: _displayDate(_date),
              ),
              const SizedBox(height: 12),
              _ConfirmationRow(label: 'Seat', value: seat.label),
              const SizedBox(height: 12),
              _ConfirmationRow(label: 'Bus type', value: assignment.acType),
              const SizedBox(height: 16),
              const Text(
                'Please verify these details before confirming.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm seat'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _bookingInProgress = true;
    });

    try {
      final booking = await widget.repository.createBooking(
        regNo: widget.session.regNo,
        assignmentId: assignment.assignmentId,
        bookingDate: _date,
        seatNumber: seat.label,
      );

      if (!mounted) return;

      setState(() {
        _existingBooking = booking;
        _selectedSeat = null;
      });
      _refreshAssignments();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Booking confirmed! Your seat is ${booking.seatNumber}.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on AppException catch (error) {
      if (!mounted) return;

      if (error.statusCode == 409) {
        final message = studentErrorMessage(
          error,
          fallback:
              'Your booking could not be completed because availability changed.',
        );
        if (error.message.toLowerCase() == 'seat already booked') {
          _showMessage(message);
          setState(() => _bookingInProgress = false);
          await _selectAssignment(assignment);
          return;
        }
        if (error.message.toLowerCase() ==
            'student already has a booking for this date') {
          _returnToDashboardForRefresh(message: message);
          return;
        }
        _showMessage(message);
        setState(() => _bookingInProgress = false);
        await _selectAssignment(assignment);
        return;
      }

      _showMessage(
        studentErrorMessage(
          error,
          fallback: 'Booking failed. Please try again.',
        ),
      );

      // Refresh the seat map in case another student booked the seat.
      setState(() {
        _bookingInProgress = false;
      });
      await _selectAssignment(assignment);
    } catch (_) {
      if (!mounted) return;

      _showMessage('Booking failed. Please check your connection and retry.');
    } finally {
      if (mounted) {
        setState(() {
          _bookingInProgress = false;
        });
      }
    }
  }

  void _returnToDashboardForRefresh({String? message}) {
    if (!mounted) return;

    _refreshAssignments();
    _showMessage(
      message ??
          'This ride is no longer available for booking. The route list has been '
              'refreshed; please choose an available ride.',
    );
    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AfternoonAssignment>>(
      future: _assignmentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(
            message: 'Loading eligible afternoon routes...',
          );
        }

        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Routes unavailable',
            message: studentErrorMessage(
              snapshot.error,
              fallback:
                  'Could not load available buses. Check your connection and try again.',
            ),
            action: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _assignmentsFuture = _loadAssignments();
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          );
        }

        final assignments = snapshot.data ?? [];
        if (!_initialAssignmentHandled && widget.initialAssignmentId != null) {
          _initialAssignmentHandled = true;
          AfternoonAssignment? initial;
          for (final item in assignments) {
            if (item.assignmentId == widget.initialAssignmentId) {
              initial = item;
              break;
            }
          }
          if (initial != null) {
            final selectedInitial = initial;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _selectAssignment(selectedInitial);
            });
          }
        }

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                _buildIntro(),
                const SizedBox(height: 20),
                if (assignments.isEmpty)
                  _EmptyPanel(
                    icon: Icons.directions_bus_outlined,
                    title: 'No eligible routes',
                    message:
                        'No eligible afternoon bus or shuttle was found for '
                        '${_weekday(_date)}, ${_displayDate(_date)}.',
                  )
                else if (_selectedAssignment == null)
                  const _EmptyPanel(
                    icon: Icons.directions_bus_outlined,
                    title: 'Choose a ride from Home',
                    message:
                        'Go back to the dashboard and select a regular route or a specific shuttle to view its seats.',
                  )
                else ...[
                  _buildAvailabilityCard(),
                  if (_loadingSeats) ...[
                    const SizedBox(height: 20),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    const Text(
                      'Loading live seat availability...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ] else if (_existingBooking != null) ...[
                    const SizedBox(height: 20),
                    _buildExistingBookingCard(),
                  ] else if (_seats.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SeatMap(
                      selectedSeat: _selectedSeat,
                      stateFor: _stateFor,
                      isSeatAvailable: _isSeatAvailable,
                      onSelected: (seat) {
                        setState(() {
                          _selectedSeat = seat;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildSelectionSummary(),
                  ] else ...[
                    const SizedBox(height: 20),
                    const _EmptyPanel(
                      icon: Icons.event_seat_outlined,
                      title: 'No seat data',
                      message:
                          'The backend returned no seat information for this route.',
                    ),
                  ],
                ],
              ],
            ),
            if (_selectedSeat != null &&
                _existingBooking == null &&
                !_loadingSeats)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(top: false, child: _buildBookingButton()),
              ),
          ],
        );
      },
    );
  }

  Widget _buildIntro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            color: Colors.white,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Booking for ${_displayDate(_date)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    final assignment = _selectedAssignment!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sky,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.directions_bus_filled_outlined,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route ${assignment.routeNumber}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  assignment.routeName,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${assignment.acType} • ${assignment.assignmentType}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!_loadingSeats && _existingBooking == null)
            Column(
              children: [
                Text(
                  '$_availableSeatCount',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const Text('available', style: TextStyle(fontSize: 11)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildExistingBookingCard() {
    final booking = _existingBooking!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB8E2C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 34),
          const SizedBox(height: 12),
          const Text(
            'You’re all set!',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'You already have a booking for this date.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _BookingDetail(label: 'SEAT', value: booking.seatNumber),
              ),
              Expanded(
                child: _BookingDetail(
                  label: 'ROUTE',
                  value: booking.routeNumber.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          BookedSeatMap(
            seatLabel: booking.seatNumber,
            bookedSeats: _bookedSeatLabels,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionSummary() {
    final seat = _selectedSeat;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: seat == null ? const Color(0xFFE1E7F0) : AppColors.blue,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_seat_outlined,
            color: AppColors.navy,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR SELECTION',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  seat == null
                      ? 'Choose an available seat'
                      : 'Seat ${seat.label}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (seat != null)
            const Icon(Icons.check_circle, color: AppColors.success),
        ],
      ),
    );
  }

  Widget _buildBookingButton() {
    return ElevatedButton.icon(
      onPressed: _selectedSeat == null || _bookingInProgress
          ? null
          : _confirmBooking,
      icon: _bookingInProgress
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.lock_outline),
      label: Text(
        _bookingInProgress ? 'Confirming booking...' : 'Confirm seat booking',
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 56),
        elevation: 5,
        shadowColor: AppColors.navy.withValues(alpha: 0.25),
      ),
    );
  }
}

class _SeatMap extends StatelessWidget {
  const _SeatMap({
    required this.selectedSeat,
    required this.stateFor,
    required this.isSeatAvailable,
    required this.onSelected,
  });

  final SeatPosition? selectedSeat;
  final SeatState Function(SeatPosition) stateFor;
  final bool Function(SeatPosition) isSeatAvailable;
  final ValueChanged<SeatPosition> onSelected;

  @override
  Widget build(BuildContext context) {
    final positions = buildSeatLayout();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your seat',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap any available seat to select it.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.airline_seat_recline_extra, size: 20),
                SizedBox(width: 8),
                Text(
                  'FRONT OF BUS',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...List.generate(11, (index) {
            final row = index + 1;

            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: seatColumns.map((column) {
                  final position = _positionFor(positions, row, column);

                  if (column == 'C' && position == null) {
                    return const Expanded(
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            'AISLE',
                            style: TextStyle(
                              color: Colors.black38,
                              fontSize: 8,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (position == null) {
                    return const Expanded(child: SizedBox(height: 42));
                  }

                  final state = stateFor(position);
                  final selected = state == SeatState.selected;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Semantics(
                        button: true,
                        label: 'Seat ${position.label}, ${state.name}',
                        child: Material(
                          color: _colorFor(state),
                          borderRadius: BorderRadius.circular(9),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: isSeatAvailable(position)
                                ? () => onSelected(position)
                                : null,
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.navy
                                      : _borderColorFor(state),
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                position.label,
                                style: TextStyle(
                                  color: _textColorFor(state),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              _Legend(color: Colors.white, label: 'Available'),
              _Legend(color: AppColors.blue, label: 'Selected'),
              _Legend(color: Colors.black38, label: 'Booked'),
              _Legend(color: AppColors.warning, label: 'Admin reserved'),
              _Legend(color: AppColors.danger, label: 'Restricted'),
            ],
          ),
        ],
      ),
    );
  }

  SeatPosition? _positionFor(
    List<SeatPosition> positions,
    int row,
    String column,
  ) {
    for (final seat in positions) {
      if (seat.row == row && seat.column == column) {
        return seat;
      }
    }
    return null;
  }

  Color _colorFor(SeatState state) {
    return switch (state) {
      SeatState.available => Colors.white,
      SeatState.selected => AppColors.blue,
      SeatState.booked => Colors.black38,
      SeatState.facultyRestricted => AppColors.warning,
      SeatState.genderRestricted => AppColors.danger,
    };
  }

  Color _textColorFor(SeatState state) {
    return state == SeatState.available ? AppColors.navy : Colors.white;
  }

  Color _borderColorFor(SeatState state) {
    return switch (state) {
      SeatState.available => const Color(0xFFCFD8E6),
      SeatState.selected => AppColors.navy,
      SeatState.booked => Colors.black38,
      SeatState.facultyRestricted => AppColors.warning,
      SeatState.genderRestricted => AppColors.danger,
    };
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _BookingDetail extends StatelessWidget {
  const _BookingDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: Colors.black38),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }
}
