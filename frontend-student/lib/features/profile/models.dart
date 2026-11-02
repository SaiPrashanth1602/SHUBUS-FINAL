class TransportProfile {
  final String regNo;
  final String studentName;
  final String morningRouteNumber;
  final String morningRouteName;
  final String acType;

  const TransportProfile({
    required this.regNo,
    required this.studentName,
    required this.morningRouteNumber,
    required this.morningRouteName,
    required this.acType,
  });

  factory TransportProfile.fromJson(Map<String, dynamic> json) {
    return TransportProfile(
      regNo: (json['regNo'] ?? '').toString(),
      studentName: (json['studentName'] ?? '').toString(),
      morningRouteNumber: (json['morningRouteNumber'] ?? '').toString(),
      morningRouteName: (json['morningRouteName'] ?? '').toString(),
      acType: (json['acType'] ?? '').toString(),
    );
  }
}
