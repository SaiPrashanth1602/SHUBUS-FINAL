import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/route_model.dart';

class RouteService {
  final String apiUrl = 'http://192.168.1.5:8081';

  Future<List<RouteModel>> getRoutes() async {
    final response = await http.get(Uri.parse('$apiUrl/api/admin/routes'));

    if (response.statusCode != 200) {
      throw Exception('Failed to load routes');
    }

    final List<dynamic> data = jsonDecode(response.body);

    return data.map((json) => RouteModel.fromJson(json)).toList();
  }

  Future<RouteModel> createRoute({
    required String routeNumber,
    required String routeName,
    required String acType,
    required List<String> allowedRoutes,
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/api/admin/routes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'routeNumber': routeNumber,
        'routeName': routeName,
        'acType': acType,
        'allowedRoutes': allowedRoutes,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create route');
    }

    return RouteModel.fromJson(jsonDecode(response.body));
  }

  Future<RouteModel> updateRoute({
    required int id,
    required String routeNumber,
    required String routeName,
    required String acType,
    required List<String> allowedRoutes,
  }) async {
    final response = await http.put(
      Uri.parse('$apiUrl/api/admin/routes/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'routeNumber': routeNumber,
        'routeName': routeName,
        'acType': acType,
        'allowedRoutes': allowedRoutes,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update route');
    }

    return RouteModel.fromJson(jsonDecode(response.body));
  }

  Future<void> deleteRoute(int id) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/api/admin/routes/$id'),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete route');
    }
  }

  Future<void> assignRoutes({
    required DateTime date,
    required List<int> routeIds,
    required String assignmentType,
    String? shuttleGroup,
  }) async {
    final formattedDate =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final response = await http.post(
      Uri.parse('$apiUrl/api/admin/afternoon-routes/bulk'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'date': formattedDate,
        'routeIds': routeIds,
        'assignmentType': assignmentType,
        'shuttleGroup': shuttleGroup,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to assign routes: ${response.statusCode}');
    }
  }

  Future<void> deleteAssignment(int assignmentId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/api/admin/afternoon-routes/$assignmentId'),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to de-assign route: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getTomorrowSchedule(DateTime date) async {
    final formattedDate =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final response = await http.get(
      Uri.parse('$apiUrl/api/admin/schedule?date=$formattedDate'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load schedule: ${response.statusCode}');
    }

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getDashboardOverview(DateTime date) async {
    final formattedDate =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final response = await http.get(
      Uri.parse('$apiUrl/api/admin/dashboard?date=$formattedDate'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load dashboard: ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
