import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _configured = String.fromEnvironment('API_BASE_URL');

  /// Endereço da API. Sobrescreva com --dart-define=API_BASE_URL=... (produção e aparelho físico).
  ///
  /// Sem isso, o padrão de desenvolvimento é o computador que roda a API: no emulador Android o
  /// "localhost" é o próprio emulador, então o computador é http://10.0.2.2:8080.
  static String get apiBaseUrl => resolve(_configured, isAndroid: defaultTargetPlatform == TargetPlatform.android && !kIsWeb);

  /// Regra de escolha do endereço (separada para poder ser testada).
  static String resolve(String configured, {required bool isAndroid}) {
    if (configured.isNotEmpty) return configured;
    return isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
  }
}
