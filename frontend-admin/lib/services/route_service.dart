import 'dart:convert';
import 'package:http/http.dart' as http;
import 'admin_api_exception.dart';
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

  AdminApiException _responseError(
    http.Response response, {
    required String fallback,
  }) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String) {
        final message = (body['error'] as String).trim();
        if (message.isNotEmpty) return AdminApiException(message);
      }
    } on FormatException {
      // Use a safe status-based message for non-JSON responses.
    }

    final message = switch (response.statusCode) {
      400 => 'Please check the information and try again.',
      401 || 403 => 'You are not allowed to make this change. Sign in again.',
      404 => 'This item could not be found. Refresh and try again.',
      409 => 'This change conflicts with existing assignments or bookings.',
      _ => fallback,
    };
    return AdminApiException(message);
  }

  AdminApiException _unexpectedResponse(String action) => AdminApiException(
    'The server returned an invalid response while trying to $action. Please try again.',
  );

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
      throw _responseError(
        response,
        fallback: 'Could not load schedules. Please try again.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw _unexpectedResponse('load schedules');
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
        throw _unexpectedResponse('load schedules');
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
      throw _responseError(
        r,
        fallback: 'Could not load routes. Please try again.',
      );
    }
    final decoded = jsonDecode(r.body);
    if (decoded is! List) throw _unexpectedResponse('load routes');
    final data = decoded;
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
      throw _responseError(
        r,
        fallback: 'Could not create the route. Please try again.',
      );
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
      throw _responseError(
        r,
        fallback: 'Could not save the route. Please try again.',
      );
    }
    return RouteModel.fromJson(jsonDecode(r.body));
  }

  Future<void> deleteRoute(int id) async {
    final r = await _delete(
      Uri.parse('$apiUrl/api/admin/routes/$id'),
    ).timeout(requestTimeout);
    if (r.statusCode != 200 && r.statusCode != 204) {
      throw _responseError(
        r,
        fallback: 'Could not delete the route. Please try again.',
      );
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
      throw _responseError(
        r,
        fallback: 'Could not assign the selected bus(es). Please try again.',
      );
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
      throw _responseError(
        r,
        fallback: 'Could not update the assignment. Please try again.',
      );
    }
  }

  Future<void> deleteAssignment(int id) async {
    final r = await _delete(
      Uri.parse('$apiUrl/api/admin/afternoon-routes/$id'),
    ).timeout(requestTimeout);
    if (r.statusCode != 200 && r.statusCode != 204) {
      throw _responseError(
        r,
        fallback: 'Could not remove the assignment. Please try again.',
      );
    }
  }

  Future<List<dynamic>> getTomorrowSchedule(DateTime d) async {
    final r = await _get(
      Uri.parse('$apiUrl/api/admin/afternoon-routes?date=${date(d)}'),
    ).timeout(requestTimeout);
    if (r.statusCode != 200) {
      throw _responseError(
        r,
        fallback: 'Could not load the schedule. Please try again.',
      );
    }
    final data = jsonDecode(r.body);
    if (data is! List) {
      throw _unexpectedResponse('load the schedule');
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
      throw _responseError(
        r,
        fallback: 'Could not load the dashboard schedule. Please try again.',
      );
    }
    final decoded = jsonDecode(r.body);
    if (decoded is! List) {
      throw _unexpectedResponse('load the dashboard schedule');
    }
    return decoded;
  }

  Future<DateTime> getCurrentOperationalDate() async {
    final r = await _get(
      Uri.parse('$apiUrl/api/admin/dashboard/operational-date'),
    ).timeout(requestTimeout);

    if (r.statusCode != 200) {
      throw _responseError(
        r,
        fallback: 'Could not load the operational date. Please try again.',
      );
    }

    final decoded = jsonDecode(r.body);

    if (decoded is! Map || decoded['operationalDate'] is! String) {
      throw _unexpectedResponse('load the operational date');
    }

    return _day(DateTime.parse(decoded['operationalDate'] as String));
  }
}
