import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

const loginPath = '/api/v1/auth/login';

Dio buildDio({
  required TokenStorage storage,
  required void Function() onUnauthorized,
  String? baseUrl,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final session = await storage.read();
        if (session != null && options.path != loginPath) {
          options.headers['Authorization'] = 'Bearer ${session.token}';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final unauthorized = error.response?.statusCode == 401 &&
            error.requestOptions.path != loginPath;
        if (unauthorized) {
          await storage.clear();
          onUnauthorized();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
}
