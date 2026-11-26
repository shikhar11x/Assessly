/// Build-time configuration. Override with:
///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
class AppConfig {
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');
}
