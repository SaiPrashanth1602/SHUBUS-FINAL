enum SeatState {
  available,
  selected,
  booked,
  facultyRestricted,
  genderRestricted,
}

/// Bus zones (must match backend SeatLayout.java):
/// rows 1-5 girls, row 6 reserved for admins/staff, rows 7-11 boys.
enum SeatZone { girls, faculty, boys }

const int girlsFirstRow = 1;
const int girlsLastRow = 5;
const int facultyRow = 6;
const int boysFirstRow = 7;
const int boysLastRow = 11;
const int totalRows = 11;

SeatZone zoneForRow(int row) {
  if (row <= girlsLastRow) return SeatZone.girls;
  if (row == facultyRow) return SeatZone.faculty;
  return SeatZone.boys;
}

class SeatPosition {
  final int row;
  final String column;

  const SeatPosition(this.row, this.column);

  String get label => '$row$column';
  int get number => _seatNumberByLabel[label] ?? 0;
  SeatZone get zone => zoneForRow(row);
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
  // Row 6 is the reserved row (centre of the bus).
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
