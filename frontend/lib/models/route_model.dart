class RouteModel {
  final int id;
  final String routeNumber, routeName, acType;
  final List<String> allowedRoutes;
  final bool defaultAfternoon;
  const RouteModel({required this.id, required this.routeNumber, required this.routeName, required this.acType, required this.allowedRoutes, required this.defaultAfternoon});
  factory RouteModel.fromJson(Map<String, dynamic> json) => RouteModel(
    id: (json['id'] as num).toInt(),
    routeNumber: '${json['routeNumber'] ?? ''}',
    routeName: '${json['routeName'] ?? ''}',
    acType: '${json['acType'] ?? 'NON_AC'}',
    allowedRoutes: List<String>.from(json['allowedRoutes'] ?? const []),
    defaultAfternoon: json['defaultAfternoon'] == true,
  );
  Map<String, dynamic> toJson() => {'id': id, 'routeNumber': routeNumber, 'routeName': routeName, 'acType': acType, 'allowedRoutes': allowedRoutes, 'defaultAfternoon': defaultAfternoon};
}
