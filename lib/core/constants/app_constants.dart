class AppConstants {
  AppConstants._();

  static const String appName = 'Assessly';
  static const String tagline = 'Smart assessments for modern colleges';

  /// Local backend URL. Override at build time with
  /// `--dart-define=API_BASE_URL=https://your-server/api`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}