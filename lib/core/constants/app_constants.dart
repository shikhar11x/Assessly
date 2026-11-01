class AppConstants {
  AppConstants._();

  static const String appName = 'Assessly';

  // Local backend. Android emulator ke liye baad mein alag handle karenge.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}