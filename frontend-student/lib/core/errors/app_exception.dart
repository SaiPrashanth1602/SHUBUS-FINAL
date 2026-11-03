class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

class ApiException extends AppException {
  const ApiException(super.message, {super.statusCode});
}

String studentErrorMessage(Object? error, {required String fallback}) {
  if (error is! AppException || error.message.trim().isEmpty) {
    return fallback;
  }

  final message = error.message.trim();
  return switch (message.toLowerCase()) {
    'registration number is required' =>
      'Enter your registration number to sign in.',
    'student not found' =>
      'We could not find a student account for that registration number.',
    'student account is inactive' =>
      'Your student account is inactive. Please contact the transport administrator.',
    'transport profile not found' =>
      'Your transport profile could not be found. Please contact the transport administrator.',
    'morning route not found' =>
      'Your assigned morning route could not be found. Please contact the transport administrator.',
    'assignment not found' =>
      'This bus is no longer available. Refresh the list and choose another bus.',
    'seat already booked' =>
      'That seat was just booked. Please choose another available seat.',
    'student already has a booking for this date' =>
      'You already have a booking for this date.',
    'booking is currently closed' =>
      'The booking window is closed for this travel date.',
    'cancellation is closed' =>
      'The cancellation window is closed for this booking.',
    'shuttle is not open for booking' =>
      'This shuttle is not open yet. Please choose an available bus or check back later.',
    'invalid seat' => 'Please select a valid seat.',
    'faculty seat cannot be booked' =>
      'That seat is reserved for an admin or staff member.',
    'girls can only book girls seats' =>
      'Please choose a seat in the girls\' seating area.',
    'boys can only book boys seats' =>
      'Please choose a seat in the boys\' seating area.',
    'this shuttle is not available for your ac/non-ac type' =>
      'This shuttle is not available for your bus type.',
    'selected route does not match your ac/non-ac profile' =>
      'This route does not match your transport profile.',
    'your morning route is not eligible for this afternoon route' =>
      'This afternoon route is not available for your assigned morning route.',
    'booking does not belong to this student' =>
      'This booking does not belong to your account.',
    'booking date does not match assignment date' =>
      'The bus availability has changed. Refresh and choose a bus again.',
    _ => message,
  };
}
