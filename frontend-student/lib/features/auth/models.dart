class StudentSession {
  final String regNo;
  final String name;
  final bool active;
  final String message;

  const StudentSession({
    required this.regNo,
    required this.name,
    required this.active,
    required this.message,
  });

  factory StudentSession.fromJson(Map<String, dynamic> json) {
    return StudentSession(
      regNo: (json['regNo'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      active: json['active'] == true,
      message: (json['message'] ?? '').toString(),
    );
  }
}
