import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/route_model.dart';
import 'api_config.dart';

class RouteService {
  RouteService({http.Client? client}) : _client = client;

  final http.Client? _client;

  String get apiUrl => ApiConfig.baseUrl;
  static const Duration requestTimeout = Duration(seconds: 20);
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<String, String> get headers => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  String date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) {
    final client = _client;
    return client == null
        ? http.get(uri, headers: headers)
        : client.get(uri, headers: headers);
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    final client = _client;
    return client == null
        ? http.post(uri, headers: headers, body: body)
        : client.post(uri, headers: headers, body: body);
  }

  Future<http.Response> _put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    final client = _client;
    return client == null
        ? http.put(uri, headers: headers, body: body)
        : client.put(uri, headers: headers, body: body);
  }

  Future<http.Response> _delete(Uri uri, {Map<String, String>? headers}) {
    final client = _client;
    return client == null
        ? http.delete(uri, headers: headers)
        : client.delete(uri, headers: headers);
  }

  Future<Map<DateTime, List<dynamic>>> getAssignmentsForRange(
    DateTime start,
    DateTime end,
  ) async {
    final startDate = _day(start);
    final endDate = _day(end);
    if (endDate.isBefore(startDate)) {
      throw ArgumentError('End date cannot be before start date.');
    }

    final map = <DateTime, List<dynamic>>{};
    final response = await _get(
      Uri.parse(
        '$apiUrl/api/admin/afternoon-routes?date=${date(startDate)}&endDate=${date(endDate)}',
      ),
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(
        'Schedule range failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Unexpected schedule range response');
    }

    for (
      var day = startDate;
      !day.isAfter(endDate);
      day = day.add(const Duration(days: 1))
    ) {
      map[_day(day)] = [];
    }

    for (final item in decoded) {
      if (item is! Map || item['assignmentDate'] is! String) {
        throw Exception('Unexpected assignment in schedule range response');
      }
      final assignmentDate = _day(DateTime.parse(item['assignmentDate']));
      map.putIfAbsent(assignmentDate, () => []).add(item);
    }

    return map;
  }

  Future<List<RouteModel>> getRoutes() async {
    final r = await _get(
      Uri.parse('$apiUrl/api/admin/routes'),
    ).timeout(requestTimeout);
    if (r.statusCode != 200) {
      throw Exception('Load routes failed (${r.statusCode}): ${r.body}');
    }
    final data = jsonDecode(r.body) as List;
    return data
        .map((e) => RouteModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<RouteModel> createRoute({
    required String routeNumber,
    required String routeCode,
    required String routeName,
    required String acType,
    required List<String> allowedRoutes,
  }) async {
    final r = await _post(
      Uri.parse('$apiUrl/api/admin/routes'),
      headers: headers,
      body: jsonEncode({
        'routeNumber': routeNumber,
        'routeCode': routeCode,
        'routeName': routeName,
        'acType': acType,
        'allowedRoutes': allowedRoutes,
      }),
    ).timeout(requestTimeout);
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw Exception('Create route failed (${r.statusCode}): ${r.body}');
    }
    return RouteModel.fromJson(jsonDecode(r.body));
  }

  Future<RouteModel> updateRoute({
    required int id,
    required String routeNumber,
    required String routeCode,
    required String routeName,
    required String acType,
    required List<String> allowedRoutes,
  }) async {
    final r = await _put(
      Uri.parse('$apiUrl/api/admin/routes/$id'),
      headers: headers,
      body: jsonEncode({
        'routeNumber': routeNumber,
        'routeCode': routeCode,
        'routeName': routeName,
        'acType': acType,
        'allowedRoutes': allowedRoutes,
      }),
    ).timeout(requestTimeout);
    if (r.statusCode != 200) {
      throw Exception('Update route failed (${r.statusCode}): ${r.body}');
    }
    return RouteModel.fromJson(jsonDecode(r.body));
  }

  Future<void> deleteRoute(int id) async {
    final r = await _delete(
      Uri.parse('$apiUrl/api/admin/routes/$id'),
    ).timeout(requestTimeout);
    if (r.statusCode != 200 && r.statusCode != 204) {
      throw Exception('Delete route failed (${r.statusCode}): ${r.body}');
    }
  }

  Future<void> assignRoutes({
    required DateTime date,
    required List<int> routeIds,
    required String assignmentType,
    String? shuttleGroup,
  }) async {
    final r = await _post(
      Uri.parse('$apiUrl/api/admin/afternoon-routes/bulk'),
      headers: headers,
      body: jsonEncode({
        'date': this.date(date),
        'routeIds': routeIds,
        'assignmentType': assignmentType,
        'shuttleGroup': shuttleGroup,
      }),
    ).timeout(requestTimeout);
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw Exception('Assign failed (${r.statusCode}): ${r.body}');
    }
  }

  Future<void> updateAssignment({
    required int id,
    required String assignmentType,
    String? shuttleGroup,
  }) async {
    final params = <String, String>{'assignmentType': assignmentType};
    if (shuttleGroup != null && shuttleGroup.isNotEmpty) {
      params['shuttleGroup'] = shuttleGroup;
    }

    final uri = Uri.parse(
      '$apiUrl/api/admin/afternoon-routes/$id',
    ).replace(queryParameters: params);
    final r = await _put(uri, headers: headers).timeout(requestTimeout);
    if (r.statusCode != 200) {
      throw Exception('Update assignment failed (${r.statusCode}): ${r.body}');
    }
  }

  Future<void> deleteAssignment(int id) async {
    final r = await _delete(
      Uri.parse('$apiUrl/api/admin/afternoon-routes/$id'),
    ).timeout(requestTimeout);
    if (r.statusCode != 200 && r.statusCode != 204) {
      throw Exception('De-assign failed (${r.statusCode}): ${r.body}');
    }
  }

  Future<List<dynamic>> getTomorrowSchedule(DateTime d) async {
    final r = await _get(
      Uri.parse('$apiUrl/api/admin/afternoon-routes?date=${date(d)}'),
    ).timeout(requestTimeout);
    if (r.statusCode != 200) {
      throw Exception('Schedule failed (${r.statusCode}): ${r.body}');
    }
    final data = jsonDecode(r.body);
    if (data is! List) {
      throw Exception('Unexpected schedule response');
    }
    return data;
  }

  // Includes bookedSeats, availableSeats and totalSeats, unlike the
  // assignment-management endpoint above. Used by the admin dashboard.
  Future<List<dynamic>> getDashboardSchedule(DateTime d) async {
    final r = await _get(
      Uri.parse('$apiUrl/api/admin/schedule?date=${date(d)}'),
      headers: headers,
    ).timeout(requestTimeout);
    if (r.statusCode != 200) {
      throw Exception(
        'Load dashboard schedule failed (${r.statusCode}): ${r.body}',
      );
    }
    final decoded = jsonDecode(r.body);
    if (decoded is! List) {
      throw Exception('Unexpected dashboard schedule response');
    }
    return decoded;
  }
}
