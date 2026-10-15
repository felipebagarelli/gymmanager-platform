import 'package:dio/dio.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../billing/domain/billing.dart';

/// Situação da conta de recebimento do personal no provedor de pagamentos.
class PayoutAccount {
  const PayoutAccount({required this.connected, required this.chargesEnabled});

  /// Já começou o cadastro no provedor.
  final bool connected;

  /// Cadastro aprovado: os alunos já conseguem assinar.
  final bool chargesEnabled;

  factory PayoutAccount.fromJson(Map<String, dynamic> json) => PayoutAccount(
        connected: json['connected'] as bool? ?? false,
        chargesEnabled: json['chargesEnabled'] as bool? ?? false,
      );
}

/// O que o personal preenche ao criar ou editar um plano.
class PlanDraft {
  const PlanDraft({required this.name, required this.priceCents, this.description, this.active = true});

  final String name;
  final int priceCents;
  final String? description;
  final bool active;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'priceCents': priceCents,
        'description': (description == null || description!.trim().isEmpty) ? null : description!.trim(),
        'active': active,
      };
}

/// Planos, assinaturas e conta de recebimento do personal logado.
class TrainerBillingRepository {
  TrainerBillingRepository(this._dio);

  final Dio _dio;

  Future<List<Plan>> plans() => _guard(() async {
        final response = await _dio.get<List<dynamic>>('/api/v1/plans');
        return [for (final item in response.data ?? const []) Plan.fromJson(item as Map<String, dynamic>)];
      });

  Future<Plan> createPlan(PlanDraft draft) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/v1/plans', data: draft.toJson());
        return Plan.fromJson(response.data!);
      });

  /// O preço novo vale só para novas assinaturas (as atuais seguem com o valor contratado).
  Future<Plan> updatePlan(int planId, PlanDraft draft) => _guard(() async {
        final response = await _dio.put<Map<String, dynamic>>('/api/v1/plans/$planId', data: draft.toJson());
        return Plan.fromJson(response.data!);
      });

  /// Assinaturas dos alunos (as que já passaram do checkout), mais recentes primeiro.
  Future<List<Subscription>> subscriptions() => _guard(() async {
        final response = await _dio.get<List<dynamic>>('/api/v1/billing/subscriptions');
        return [for (final item in response.data ?? const []) Subscription.fromJson(item as Map<String, dynamic>)];
      });

  Future<PayoutAccount> payoutAccount() => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/v1/billing/payout-account');
        return PayoutAccount.fromJson(response.data ?? const {});
      });

  /// Link do cadastro de recebimento no provedor (abre no navegador).
  Future<String> startOnboarding() => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/v1/billing/payout-account/onboarding');
        return response.data!['url'] as String;
      });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
