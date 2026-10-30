class ApiConfig {
  ApiConfig._();

  // Override for a physical phone with:
  // flutter run --dart-define=API_BASE_URL=http://YOUR_LAPTOP_IP:8081
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.6:8081',
  );
}
