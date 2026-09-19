class AppConfig {
  /// Endereco da API. Sobrescreva com --dart-define=API_BASE_URL=...
  /// (ex.: emulador Android usa http://10.0.2.2:8080).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}
