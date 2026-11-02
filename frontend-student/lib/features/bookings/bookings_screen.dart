import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/booking_window.dart';
import '../auth/models.dart';
import '../student_repository.dart';
import 'models.dart';
import '../seat_selection/booked_seat_map.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({
    super.key,
    required this.session,
    required this.repository,
  });

  final StudentSession session;
  final StudentRepository repository;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  late DateTime _date;
  late Future<BookingInfo?> _bookingFuture;

  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _date = _targetBookingDate();
    _bookingFuture = _loadBooking();
  }

  DateTime _targetBookingDate() {
    return BookingWindow.targetBookingDate();
  }

  /// Cancellation is allowed until 1:45 PM on the travel day
  /// (same cutoff as booking; the backend is the final authority).
  bool _canCancelFor(DateTime date) {
    return BookingWindow.canCancel(DateUtils.dateOnly(date));
  }

  Future<BookingInfo?> _loadBooking() {
    return widget.repository.getBooking(
      regNo: widget.session.regNo,
      date: _date,
    );
  }

  Future<void> _refresh() async {
    final future = _loadBooking();

    setState(() {
      _bookingFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder displays the error state.
    }
  }

  Future<void> _pickDate() async {
    final today = BookingWindow.today();

    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 30)),
      lastDate: today.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.navy,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() {
      _date = DateUtils.dateOnly(selected);
      _bookingFuture = _loadBooking();
    });
  }

  Future<void> _cancelBooking(BookingInfo booking) async {
    if (!_canCancelFor(booking.bookingDate ?? _date)) {
      _showMessage('Cancellation closed at 1:45 PM on the travel day.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.event_busy_outlined,
            size: 38,
            color: AppColors.danger,
          ),
          title: const Text(
            'Cancel your booking?',
            textAlign: TextAlign.center,
          ),
          content: Text(
            'You are about to cancel seat ${booking.seatNumber} '
            'on route ${booking.routeNumber} for '
            '${_formatDate(booking.bookingDate ?? _date)}.\n\n'
            'This action cannot be undone.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep booking'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel booking'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted || _cancelling) return;

    setState(() {
      _cancelling = true;
    });

    try {
      await widget.repository.cancelBooking(
        regNo: widget.session.regNo,
        bookingId: booking.bookingId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled successfully.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _refresh();
    } on AppException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _refresh();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to cancel the booking. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _refresh();
    } finally {
      if (mounted) {
        setState(() {
          _cancelling = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDate(DateTime date) {
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

  String _formatDateTime(DateTime date) {
    final time = TimeOfDay.fromDateTime(date).format(context);
    return '${_formatDate(date)} at $time';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildHeader(),
          const SizedBox(height: 22),
          _buildDateSelector(),
          const SizedBox(height: 22),
          const Text(
            'Booking details',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'View or manage your afternoon transport booking.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FutureBuilder<BookingInfo?>(
            future: _bookingFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingPanel();
              }

              if (snapshot.hasError) {
                return _EmptyPanel(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load booking',
                  message: snapshot.error.toString(),
                  action: OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                );
              }

              final booking = snapshot.data;

              if (booking == null) {
                return _EmptyPanel(
                  icon: Icons.confirmation_number_outlined,
                  title: 'No booking found',
                  message:
                      'You do not have a booking for ${_formatDate(_date)}.',
                  action: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Choose another date'),
                  ),
                );
              }

              return _buildBookingCard(booking);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.confirmation_number_outlined,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 7),
                Text(
                  '${_weekday(_date).toUpperCase()} • ${_formatDate(_date)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'My bookings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Your seat, route and travel details in one place.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.session.regNo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh booking',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.sky,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TRAVEL DATE',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _weekday(_date),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _formatDate(_date),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _cancelling ? null : _pickDate,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(BookingInfo booking) {
    final canCancel = _canCancelFor(booking.bookingDate ?? _date);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E7F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            color: const Color(0xFFEAF7EF),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canCancel ? 'Booking confirmed' : 'Booking locked',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        canCancel
                            ? 'Your seat has been reserved.'
                            : 'Your seat is confirmed. Cancellation closed at 1:45 PM.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR SEAT',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        booking.seatNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Route ${booking.routeNumber}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            booking.routeName,
                            style: const TextStyle(
                              color: Colors.black54,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Travel date',
                  value: _formatDate(booking.bookingDate ?? _date),
                ),
                _DetailRow(
                  icon: Icons.directions_bus_outlined,
                  label: 'Bus type',
                  value: booking.acType,
                ),
                _DetailRow(
                  icon: Icons.category_outlined,
                  label: 'Booking type',
                  value: booking.assignmentType,
                ),
                if (booking.shuttleGroup.isNotEmpty)
                  _DetailRow(
                    icon: Icons.groups_outlined,
                    label: 'Shuttle group',
                    value: booking.shuttleGroup,
                  ),
                _DetailRow(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Booking ID',
                  value: booking.bookingId.toString(),
                ),
                if (booking.bookedAt != null)
                  _DetailRow(
                    icon: Icons.access_time_outlined,
                    label: 'Booked at',
                    value: _formatDateTime(booking.bookedAt!),
                  ),
                const SizedBox(height: 4),
                BookedSeatMapLoader(
                  repository: widget.repository,
                  regNo: widget.session.regNo,
                  assignmentId: booking.assignmentId,
                  date: booking.bookingDate ?? _date,
                  seatLabel: booking.seatNumber,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: canCancel && !_cancelling
                        ? () => _cancelBooking(booking)
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      minimumSize: const Size(0, 50),
                    ),
                    icon: _cancelling
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.event_busy_outlined),
                    label: Text(
                      _cancelling
                          ? 'Cancelling...'
                          : canCancel
                          ? 'Cancel booking'
                          : 'Cancellation closed',
                    ),
                  ),
                ),
                if (canCancel) ...[
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'You can cancel until 1:45 PM on the travel day.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.navy),
          const SizedBox(width: 12),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading your booking...',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Colors.black38),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: action),
          ],
        ],
      ),
    );
  }
}
