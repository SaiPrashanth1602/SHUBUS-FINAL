import 'dart:async';

import 'package:http/http.dart' as http;

class AdminApiException implements Exception {
  const AdminApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

String adminErrorMessage(Object error, {required String fallback}) {
  if (error is AdminApiException) return error.message;
  if (error is TimeoutException || error is http.ClientException) {
    return 'Could not connect to the server. Check your connection and try again.';
  }
  return fallback;
}
