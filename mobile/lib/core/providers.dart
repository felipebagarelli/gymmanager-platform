import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/api_client.dart';
import 'storage/token_storage.dart';
import '../features/auth/application/auth_controller.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

final dioProvider = Provider<Dio>((ref) {
  return buildDio(
    storage: ref.watch(tokenStorageProvider),
    onUnauthorized: () => ref.read(authControllerProvider.notifier).sessionExpired(),
  );
});

/// Relógio do app. Os cronômetros usam este provider para que os testes controlem o tempo.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Pulso de 1 segundo dos cronômetros (execução e descanso). É broadcast porque os dois
/// cronômetros podem escutar ao mesmo tempo (o Timer só roda enquanto houver ouvinte). Nos testes é trocado por um
/// StreamController, porque um Timer periódico impediria o `pumpAndSettle` de terminar.
final secondTickerProvider =
    Provider<Stream<void>>((ref) => Stream<void>.periodic(const Duration(seconds: 1)).asBroadcastStream());
