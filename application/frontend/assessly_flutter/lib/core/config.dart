/// Build-time configuration. Override with:
///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
/// The Docker image uses API_BASE_URL=same-origin, so calls go to /api on the serving host.
class AppConfig {
  static const String _raw =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');

  static String resolve(String raw) => raw == 'same-origin' ? '' : raw;

  static String get apiBaseUrl => resolve(_raw);
}
