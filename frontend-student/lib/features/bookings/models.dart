class BookingInfo {
  final int bookingId;
  final String regNo;
  final int assignmentId;
  final String routeNumber;
  final String routeName;
  final String acType;
  final String assignmentType;
  final String shuttleGroup;
  final DateTime? bookingDate;
  final String seatNumber;
  final DateTime? bookedAt;

  const BookingInfo({
    required this.bookingId,
    required this.regNo,
    required this.assignmentId,
    required this.routeNumber,
    required this.routeName,
    required this.acType,
    required this.assignmentType,
    required this.shuttleGroup,
    required this.bookingDate,
    required this.seatNumber,
    required this.bookedAt,
  });

  factory BookingInfo.fromJson(Map<String, dynamic> json) {
    return BookingInfo(
      bookingId: (json['bookingId'] as num?)?.toInt() ?? 0,
      regNo: (json['regNo'] ?? '').toString(),
      assignmentId: (json['assignmentId'] as num?)?.toInt() ?? 0,
      routeNumber: (json['routeNumber'] ?? '').toString(),
      routeName: (json['routeName'] ?? '').toString(),
      acType: (json['acType'] ?? '').toString(),
      assignmentType: (json['assignmentType'] ?? '').toString(),
      shuttleGroup: (json['shuttleGroup'] ?? '').toString(),
      bookingDate: DateTime.tryParse((json['bookingDate'] ?? '').toString()),
      seatNumber: (json['seatNumber'] ?? '').toString(),
      bookedAt: DateTime.tryParse((json['bookedAt'] ?? '').toString()),
    );
  }
}
