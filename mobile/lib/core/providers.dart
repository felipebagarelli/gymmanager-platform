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
