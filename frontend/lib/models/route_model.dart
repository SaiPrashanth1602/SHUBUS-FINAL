class RouteModel {
  final int id;
  final String routeNumber;
  final String routeName;
  final String acType;
  final List<String> allowedRoutes;
  final bool defaultAfternoon;

  RouteModel({
    required this.id,
    required this.routeNumber,
    required this.routeName,
    required this.acType,
    required this.allowedRoutes,
    required this.defaultAfternoon,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'],
      routeNumber: json['routeNumber'],
      routeName: json['routeName'],
      acType: json['acType'],
      allowedRoutes: List<String>.from(json['allowedRoutes'] ?? []),
      defaultAfternoon: json['defaultAfternoon'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'routeNumber': routeNumber,
      'routeName': routeName,
      'acType': acType,
      'allowedRoutes': allowedRoutes,
      'defaultAfternoon': defaultAfternoon,
    };
  }
}
