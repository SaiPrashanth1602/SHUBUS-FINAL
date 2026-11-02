enum SeatState {
  available,
  selected,
  booked,
  facultyRestricted,
  genderRestricted,
}

class SeatPosition {
  final int row;
  final String column;

  const SeatPosition(this.row, this.column);

  String get label => '$row$column';
  int get number => _seatNumberByLabel[label] ?? 0;
}

class SeatViewModel {
  final SeatPosition position;
  final SeatState state;

  const SeatViewModel({required this.position, required this.state});

  bool get canSelect =>
      state == SeatState.available || state == SeatState.selected;
}

const List<String> seatColumns = ['A', 'B', 'C', 'D', 'E', 'F'];

List<SeatPosition> buildSeatLayout() {
  final positions = <SeatPosition>[];

  // Front row has four seats around the aisle.
  positions.addAll(
    ['A', 'D', 'E', 'F'].map((column) => SeatPosition(1, column)),
  );

  // Rows 2-10 use the standard 2 + 3 seating arrangement.
  // Row 6 is the additional row inserted after the faculty row (row 5).
  for (var row = 2; row <= 10; row++) {
    positions.addAll(
      ['A', 'B', 'D', 'E', 'F'].map((column) => SeatPosition(row, column)),
    );
  }

  // Rear row has six seats.
  positions.addAll(seatColumns.map((column) => SeatPosition(11, column)));
  return positions;
}

final Map<String, int> _seatNumberByLabel = {
  for (final entry in buildSeatLayout().asMap().entries)
    entry.value.label: entry.key + 1,
};
