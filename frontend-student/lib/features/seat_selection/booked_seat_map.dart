import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../student_repository.dart';
import 'seat_layout.dart';

/// Read-only bus layout using the same colours as the seat picker:
/// your seat = navy, faculty = yellow, other gender's area = red,
/// seats booked by others = grey, free seats = white (not tappable).
class BookedSeatMap extends StatelessWidget {
  const BookedSeatMap({
    super.key,
    required this.seatLabel,
    this.bookedSeats = const <String>{},
  });

  /// The student's own seat, for example "9E".
  final String seatLabel;

  /// Seats booked by other students (optional). Free seats stay white.
  final Set<String> bookedSeats;

  /// Girls sit in rows 1-5 and boys in rows 7-11, so the student's own seat
  /// tells us which area is restricted for them.
  SeatZone? _ownZone(String mySeat) {
    final digits = RegExp(r'^\d+').firstMatch(mySeat)?.group(0);
    final row = int.tryParse(digits ?? '');
    if (row == null) return null;

    final zone = zoneForRow(row);
    return zone == SeatZone.faculty ? null : zone;
  }

  @override
  Widget build(BuildContext context) {
    final mySeat = seatLabel.trim().toUpperCase();
    final ownZone = _ownZone(mySeat);
    final positions = buildSeatLayout();

    return IgnorePointer(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE1E7F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Where you sit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              'Seat $mySeat is highlighted. This view is read-only.',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.airline_seat_recline_extra, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'FRONT OF BUS',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(totalRows, (index) {
              final row = index + 1;

              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: seatColumns.map((column) {
                    SeatPosition? position;
                    for (final p in positions) {
                      if (p.row == row && p.column == column) {
                        position = p;
                        break;
                      }
                    }

                    if (position == null) {
                      return const Expanded(child: SizedBox(height: 36));
                    }

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: _cell(position, mySeat, ownZone),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 14,
              runSpacing: 10,
              children: [
                _MapLegend(
                  fill: Colors.white,
                  border: Color(0xFFCFD8E6),
                  label: 'Available',
                ),
                _MapLegend(
                  fill: AppColors.navy,
                  border: AppColors.navy,
                  label: 'Your seat',
                ),
                _MapLegend(
                  fill: Colors.black38,
                  border: Colors.black38,
                  label: 'Booked',
                ),
                _MapLegend(
                  fill: AppColors.warning,
                  border: AppColors.warning,
                  label: 'Faculty',
                ),
                _MapLegend(
                  fill: AppColors.danger,
                  border: AppColors.danger,
                  label: 'Restricted',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(SeatPosition position, String mySeat, SeatZone? ownZone) {
    final isMine = position.label == mySeat;

    Color fill;
    Color border;
    Color text;

    if (isMine) {
      fill = AppColors.navy;
      border = AppColors.navy;
      text = Colors.white;
    } else if (position.zone == SeatZone.faculty) {
      fill = AppColors.warning;
      border = AppColors.warning;
      text = Colors.white;
    } else if (ownZone != null && position.zone != ownZone) {
      fill = AppColors.danger;
      border = AppColors.danger;
      text = Colors.white;
    } else if (bookedSeats.contains(position.label)) {
      fill = Colors.black38;
      border = Colors.black38;
      text = Colors.white;
    } else {
      fill = Colors.white;
      border = const Color(0xFFCFD8E6);
      text = AppColors.navy;
    }

    return Semantics(
      label: isMine ? 'Your seat ${position.label}' : 'Seat ${position.label}',
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: border, width: isMine ? 2 : 1),
        ),
        child: Text(
          position.label,
          style: TextStyle(
            color: text,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Loads which seats are booked by others, then shows [BookedSeatMap].
/// If the seat API refuses (for example booking is closed), the map still
/// shows with free seats in white, so the ticket never breaks.
class BookedSeatMapLoader extends StatefulWidget {
  const BookedSeatMapLoader({
    super.key,
    required this.repository,
    required this.regNo,
    required this.assignmentId,
    required this.date,
    required this.seatLabel,
  });

  final StudentRepository repository;
  final String regNo;
  final int? assignmentId;
  final DateTime date;
  final String seatLabel;

  @override
  State<BookedSeatMapLoader> createState() => _BookedSeatMapLoaderState();
}

class _BookedSeatMapLoaderState extends State<BookedSeatMapLoader> {
  late Future<Set<String>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant BookedSeatMapLoader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.assignmentId != widget.assignmentId ||
        oldWidget.date != widget.date ||
        oldWidget.seatLabel != widget.seatLabel) {
      _future = _load();
    }
  }

  Future<Set<String>> _load() async {
    final id = widget.assignmentId;
    if (id == null) return <String>{};

    try {
      final seats = await widget.repository.getSeats(
        regNo: widget.regNo,
        assignmentId: id,
        date: widget.date,
      );

      return {
        for (final seat in seats)
          if ((seat['status'] ?? '').toString().toUpperCase() == 'BOOKED')
            (seat['seatNumber'] ?? '').toString(),
      };
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<String>>(
      future: _future,
      builder: (context, snapshot) {
        return BookedSeatMap(
          seatLabel: widget.seatLabel,
          bookedSeats: snapshot.data ?? const <String>{},
        );
      },
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({
    required this.fill,
    required this.border,
    required this.label,
  });

  final Color fill;
  final Color border;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10.5)),
      ],
    );
  }
}
