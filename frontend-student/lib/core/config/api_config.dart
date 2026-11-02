class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.7:8081',
  );
  static const timeout = Duration(seconds: 12);

  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    final root = Uri.parse(baseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return root.replace(
      path: '${root.path}$normalizedPath'.replaceAll('//', '/'),
      queryParameters: queryParameters,
    );
  }
}
