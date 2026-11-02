import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../errors/app_exception.dart';

class ApiClient {
  ApiClient({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;

  Future<dynamic> getJson(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _send(
      () => _client.get(
        ApiConfig.uri(path, queryParameters),
        headers: const {'Accept': 'application/json'},
      ),
    );

    return _decode(response);
  }

  Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    final response = await _send(
      () => _client.post(
        ApiConfig.uri(path),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ),
    );

    return _decode(response);
  }

  Future<dynamic> deleteJson(String path) async {
    final response = await _send(
      () => _client.delete(
        ApiConfig.uri(path),
        headers: const {'Accept': 'application/json'},
      ),
    );

    return _decode(response);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(ApiConfig.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _messageForStatus(response.statusCode, response.body),
          statusCode: response.statusCode,
        );
      }

      return response;
    } on TimeoutException {
      throw const NetworkException('The server took too long to respond.');
    } on SocketException {
      throw const NetworkException(
        'Cannot reach the SHUBUS backend. Check your connection.',
      );
    } on http.ClientException {
      throw const NetworkException(
        'Network request failed. Check the backend connection.',
      );
    }
  }

  dynamic _decode(http.Response response) {
    if (response.body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const ApiException('The server returned invalid JSON.');
    }
  }

  String _messageForStatus(int statusCode, String body) {
    // Prefer a useful error message returned by the backend.
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        for (final key in ['message', 'error', 'detail']) {
          final value = decoded[key];

          if (value is String && value.trim().isNotEmpty) {
            return value;
          }
        }
      }
    } on FormatException {
      // Fall through to the standard HTTP error message.
    }

    return switch (statusCode) {
      400 => 'Check the details and try again.',
      401 => 'Your session is not authorized. Please sign in again.',
      403 => 'You are not allowed to perform this action.',
      404 => 'The requested information was not found.',
      409 => 'This request conflicts with the latest server state.',
      422 => 'The server could not process the submitted details.',
      >= 500 => 'The SHUBUS server encountered an error.',
      _ => 'Request failed with status $statusCode.',
    };
  }

  void close() {
    _client.close();
  }
}
