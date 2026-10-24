import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/route_model.dart';

class RouteService {
  final String apiUrl = 'http://192.168.0.6:8081';
  Map<String, String> get headers => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  String date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<RouteModel>> getRoutes() async {
    final r = await http.get(Uri.parse('$apiUrl/api/admin/routes'));
    if (r.statusCode != 200)
      throw Exception('Load routes failed (${r.statusCode}): ${r.body}');
    final data = jsonDecode(r.body) as List;
    return data
        .map((e) => RouteModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<RouteModel> createRoute({
    required String routeNumber,
    required String routeName,
    required String acType,
    required List<String> allowedRoutes,
  }) async {
    final r = await http.post(
      Uri.parse('$apiUrl/api/admin/routes'),
      headers: headers,
      body: jsonEncode({
        'routeNumber': routeNumber,
        'routeName': routeName,
        'acType': acType,
        'allowedRoutes': allowedRoutes,
      }),
    );
    if (r.statusCode != 200 && r.statusCode != 201)
      throw Exception('Create route failed (${r.statusCode}): ${r.body}');
    return RouteModel.fromJson(jsonDecode(r.body));
  }

  Future<RouteModel> updateRoute({
    required int id,
    required String routeNumber,
    required String routeName,
    required String acType,
    required List<String> allowedRoutes,
  }) async {
    final r = await http.put(
      Uri.parse('$apiUrl/api/admin/routes/$id'),
      headers: headers,
      body: jsonEncode({
        'routeNumber': routeNumber,
        'routeName': routeName,
        'acType': acType,
        'allowedRoutes': allowedRoutes,
      }),
    );
    if (r.statusCode != 200)
      throw Exception('Update route failed (${r.statusCode}): ${r.body}');
    return RouteModel.fromJson(jsonDecode(r.body));
  }

  Future<void> deleteRoute(int id) async {
    final r = await http.delete(Uri.parse('$apiUrl/api/admin/routes/$id'));
    if (r.statusCode != 200 && r.statusCode != 204)
      throw Exception('Delete route failed (${r.statusCode}): ${r.body}');
  }

  Future<void> assignRoutes({
    required DateTime date,
    required List<int> routeIds,
    required String assignmentType,
    String? shuttleGroup,
  }) async {
    final r = await http.post(
      Uri.parse('$apiUrl/api/admin/afternoon-routes/bulk'),
      headers: headers,
      body: jsonEncode({
        'date': this.date(date),
        'routeIds': routeIds,
        'assignmentType': assignmentType,
        'shuttleGroup': shuttleGroup,
      }),
    );
    if (r.statusCode != 200 && r.statusCode != 201)
      throw Exception('Assign failed (${r.statusCode}): ${r.body}');
  }

  Future<void> deleteAssignment(int id) async {
    final r = await http.delete(
      Uri.parse('$apiUrl/api/admin/afternoon-routes/$id'),
    );
    if (r.statusCode != 200 && r.statusCode != 204)
      throw Exception('De-assign failed (${r.statusCode}): ${r.body}');
  }

  Future<List<dynamic>> getTomorrowSchedule(DateTime d) async {
    final r = await http.get(
      Uri.parse('$apiUrl/api/admin/afternoon-routes?date=${date(d)}'),
    );
    if (r.statusCode != 200)
      throw Exception('Schedule failed (${r.statusCode}): ${r.body}');
    final data = jsonDecode(r.body);
    if (data is! List) throw Exception('Unexpected schedule response');
    return data;
  }

  Future<Map<String, dynamic>> getDashboardOverview(DateTime d) async {
    final r = await http.get(
      Uri.parse('$apiUrl/api/admin/dashboard?date=${date(d)}'),
    );
    if (r.statusCode != 200)
      throw Exception('Dashboard failed (${r.statusCode}): ${r.body}');
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }
}
