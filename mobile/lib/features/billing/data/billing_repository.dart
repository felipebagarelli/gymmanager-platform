import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/billing.dart';

class BillingRepository {
  BillingRepository(this._dio);

  final Dio _dio;

  Future<List<Plan>> availablePlans() => _guard(() async {
        final response = await _dio.get<List<dynamic>>('/api/v1/plans/available');
        return [for (final item in response.data ?? const []) Plan.fromJson(item as Map<String, dynamic>)];
      });

  /// Null quando o aluno ainda nao tem assinatura (a API responde 204).
  Future<Subscription?> mySubscription() => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/v1/subscriptions/me');
        final data = response.data;
        return data == null || data.isEmpty ? null : Subscription.fromJson(data);
      });

  /// Devolve a URL do checkout (pagina de pagamento do provedor).
  Future<String> subscribe(int planId) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/subscriptions',
          data: {'planId': planId},
        );
        return response.data!['url'] as String;
      });

  Future<void> cancel() => _guard(() => _dio.post<void>('/api/v1/subscriptions/me/cancel'));

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
