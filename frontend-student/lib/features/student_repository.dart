import '../core/network/api_client.dart';
import 'auth/models.dart';
import 'bookings/models.dart';
import 'profile/models.dart';
import 'routes/models.dart';
import '../core/errors/app_exception.dart';

class StudentRepository {
  StudentRepository(this._apiClient);

  final ApiClient _apiClient;

  // --------------------------------------------------
  // AUTHENTICATION
  // --------------------------------------------------

  Future<StudentSession> login({required String regNo}) async {
    final json = await _apiClient.postJson('/api/auth/login', {'regNo': regNo});

    return StudentSession.fromJson(json as Map<String, dynamic>);
  }

  // --------------------------------------------------
  // TRANSPORT PROFILE
  // --------------------------------------------------

  Future<TransportProfile> getTransportProfile(String regNo) async {
    final json = await _apiClient.getJson(
      '/api/students/${Uri.encodeComponent(regNo)}/transport-profile',
    );

    return TransportProfile.fromJson(json as Map<String, dynamic>);
  }

  // --------------------------------------------------
  // ROUTES
  // --------------------------------------------------

  Future<List<RouteInfo>> getRoutes() async {
    final json = await _apiClient.getJson('/api/admin/routes');

    return (json as List<dynamic>)
        .map((item) => RouteInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // --------------------------------------------------
  // AFTERNOON ASSIGNMENTS
  // --------------------------------------------------

  Future<List<AfternoonAssignment>> getAfternoonAssignments({
    required String regNo,
    required DateTime date,
  }) async {
    final json = await _apiClient.getJson(
      '/api/students/${Uri.encodeComponent(regNo)}/afternoon-routes',
      queryParameters: {'date': _dateOnly(date)},
    );

    return (json as List<dynamic>)
        .map(
          (item) => AfternoonAssignment.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  // --------------------------------------------------
  // SEAT AVAILABILITY
  // --------------------------------------------------

  Future<List<Map<String, dynamic>>> getSeats({
    required String regNo,
    required int assignmentId,
    required DateTime date,
  }) async {
    final json = await _apiClient.getJson(
      '/api/students/${Uri.encodeComponent(regNo)}'
      '/afternoon-routes/$assignmentId/seats',
      queryParameters: {'date': _dateOnly(date)},
    );

    return (json as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  // --------------------------------------------------
  // CREATE BOOKING
  // --------------------------------------------------

  Future<BookingInfo> createBooking({
    required String regNo,
    required int assignmentId,
    required DateTime bookingDate,
    required String seatNumber,
  }) async {
    final json = await _apiClient.postJson('/api/students/bookings', {
      'regNo': regNo,
      'assignmentId': assignmentId,
      'bookingDate': _dateOnly(bookingDate),
      'seatNumber': seatNumber,
    });

    return BookingInfo.fromJson(json as Map<String, dynamic>);
  }

  // --------------------------------------------------
  // BOOKING HISTORY
  // --------------------------------------------------

  Future<BookingInfo?> getBooking({
    required String regNo,
    required DateTime date,
  }) async {
    try {
      final json = await _apiClient.getJson(
        '/api/students/${Uri.encodeComponent(regNo)}/bookings',
        queryParameters: {'date': _dateOnly(date)},
      );

      if (json is! Map<String, dynamic>) {
        return null;
      }

      // Some backend responses indicate that no booking exists
      // using HTTP 200 with an error message.
      final errorMessage = json['error'];

      if (errorMessage is String &&
          errorMessage.toLowerCase().contains('no booking found')) {
        return null;
      }

      return BookingInfo.fromJson(json);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }

      rethrow;
    }
  }

  // --------------------------------------------------
  // CANCEL BOOKING
  // --------------------------------------------------

  Future<void> cancelBooking({
    required String regNo,
    required int bookingId,
  }) async {
    await _apiClient.deleteJson(
      '/api/students/${Uri.encodeComponent(regNo)}/bookings/$bookingId',
    );
  }

  // --------------------------------------------------
  // DATE FORMATTING
  // --------------------------------------------------

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }
}
