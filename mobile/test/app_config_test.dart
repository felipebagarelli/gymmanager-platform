import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/config/app_config.dart';

void main() {
  test('endereço configurado (--dart-define) sempre vence', () {
    expect(AppConfig.resolve('https://api.exemplo.com', isAndroid: true), 'https://api.exemplo.com');
    expect(AppConfig.resolve('http://192.168.0.10:8080', isAndroid: false), 'http://192.168.0.10:8080');
  });

  test('sem configuração, o emulador Android usa o computador (10.0.2.2)', () {
    expect(AppConfig.resolve('', isAndroid: true), 'http://10.0.2.2:8080');
  });

  test('sem configuração, as demais plataformas usam localhost', () {
    expect(AppConfig.resolve('', isAndroid: false), 'http://localhost:8080');
  });
}
