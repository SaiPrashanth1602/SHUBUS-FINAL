class RouteInfo {
  final int id;
  final String routeNumber;
  final String routeName;
  final String acType;
  final List<String> allowedRoutes;
  final bool defaultAfternoon;

  const RouteInfo({
    required this.id,
    required this.routeNumber,
    required this.routeName,
    required this.acType,
    required this.allowedRoutes,
    required this.defaultAfternoon,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    return RouteInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      routeNumber: (json['routeNumber'] ?? '').toString(),
      routeName: (json['routeName'] ?? '').toString(),
      acType: (json['acType'] ?? '').toString(),
      allowedRoutes: (json['allowedRoutes'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      defaultAfternoon: json['defaultAfternoon'] == true,
    );
  }
}

class AfternoonAssignment {
  final int assignmentId;
  final int routeId;
  final String routeNumber;
  final String routeName;
  final String acType;
  final String assignmentType;
  final String shuttleGroup;
  final DateTime? assignmentDate;
  final int totalSeats;
  final int bookedSeats;
  final int availableSeats;
  final int studentGenderCapacity;
  final int availableSeatsForStudent;
  final bool isOpen;

  const AfternoonAssignment({
    required this.assignmentId,
    required this.routeId,
    required this.routeNumber,
    required this.routeName,
    required this.acType,
    required this.assignmentType,
    required this.shuttleGroup,
    required this.assignmentDate,
    required this.totalSeats,
    required this.bookedSeats,
    required this.availableSeats,
    required this.studentGenderCapacity,
    required this.availableSeatsForStudent,
    required this.isOpen,
  });

  factory AfternoonAssignment.fromJson(Map<String, dynamic> json) {
    return AfternoonAssignment(
      assignmentId: (json['assignmentId'] as num?)?.toInt() ?? 0,
      routeId: (json['routeId'] as num?)?.toInt() ?? 0,
      routeNumber: (json['routeNumber'] ?? '').toString(),
      routeName: (json['routeName'] ?? '').toString(),
      acType: (json['acType'] ?? '').toString(),
      assignmentType: (json['assignmentType'] ?? '').toString(),
      shuttleGroup: (json['shuttleGroup'] ?? '').toString(),
      assignmentDate: DateTime.tryParse(
        (json['assignmentDate'] ?? '').toString(),
      ),
      totalSeats: (json['totalSeats'] as num?)?.toInt() ?? 0,
      bookedSeats: (json['bookedSeats'] as num?)?.toInt() ?? 0,
      availableSeats: (json['availableSeats'] as num?)?.toInt() ?? 0,
      studentGenderCapacity:
          (json['studentGenderCapacity'] as num?)?.toInt() ?? 0,
      availableSeatsForStudent:
          (json['availableSeatsForStudent'] as num?)?.toInt() ?? 0,
      isOpen: json['isOpen'] == true,
    );
  }
}
