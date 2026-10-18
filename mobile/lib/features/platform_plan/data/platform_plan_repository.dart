import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';

enum PlanTier { free, pro }

enum PlatformSubStatus { trialing, active, pastDue, canceled, pending }

PlatformSubStatus _status(String? api) => switch (api) {
      'TRIALING' => PlatformSubStatus.trialing,
      'ACTIVE' => PlatformSubStatus.active,
      'PAST_DUE' => PlatformSubStatus.pastDue,
      'CANCELED' => PlatformSubStatus.canceled,
      _ => PlatformSubStatus.pending,
    };

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

class PlatformSubscriptionInfo {
  const PlatformSubscriptionInfo({
    required this.status,
    required this.yearly,
    required this.priceCents,
    this.currentPeriodEnd,
    this.trialEnd,
    this.cancelAtPeriodEnd = false,
  });

  final PlatformSubStatus status;
  final bool yearly;
  final int priceCents;
  final DateTime? currentPeriodEnd;
  final DateTime? trialEnd;
  final bool cancelAtPeriodEnd;

  factory PlatformSubscriptionInfo.fromJson(Map<String, dynamic> json) => PlatformSubscriptionInfo(
        status: _status(json['status'] as String?),
        yearly: json['interval'] == 'YEARLY',
        priceCents: (json['priceCents'] as num).toInt(),
        currentPeriodEnd: _date(json['currentPeriodEnd']),
        trialEnd: _date(json['trialEnd']),
        cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
      );
}

/// Plano da plataforma do aluno sem personal: grátis ou Pro, preços e o que cada um libera.
class PlatformPlanStatus {
  const PlatformPlanStatus({
    required this.tier,
    this.subscription,
    required this.monthlyCents,
    required this.yearlyCents,
    required this.trialDays,
    required this.trialAvailable,
    this.aiWorkoutsPerMonth,
    required this.canSubscribe,
    this.unavailableReason,
  });

  final PlanTier tier;
  final PlatformSubscriptionInfo? subscription;
  final int monthlyCents;
  final int yearlyCents;
  final int trialDays;
  final bool trialAvailable;

  /// null = sem limite (Pro).
  final int? aiWorkoutsPerMonth;
  final bool canSubscribe;
  final String? unavailableReason;

  bool get isPro => tier == PlanTier.pro;

  /// Quanto o anual economiza em relação a 12 meses do mensal (em %).
  int get yearlySavingPercent =>
      monthlyCents <= 0 ? 0 : (100 - (yearlyCents * 100 / (monthlyCents * 12))).round().clamp(0, 100);

  factory PlatformPlanStatus.fromJson(Map<String, dynamic> json) {
    final offer = json['offer'] as Map<String, dynamic>? ?? const {};
    final sub = json['subscription'] as Map<String, dynamic>?;
    return PlatformPlanStatus(
      tier: json['tier'] == 'PRO' ? PlanTier.pro : PlanTier.free,
      subscription: sub == null ? null : PlatformSubscriptionInfo.fromJson(sub),
      monthlyCents: (offer['monthlyCents'] as num?)?.toInt() ?? 0,
      yearlyCents: (offer['yearlyCents'] as num?)?.toInt() ?? 0,
      trialDays: (offer['trialDays'] as num?)?.toInt() ?? 0,
      trialAvailable: offer['trialAvailable'] as bool? ?? false,
      aiWorkoutsPerMonth: (json['aiWorkoutsPerMonth'] as num?)?.toInt(),
      canSubscribe: json['canSubscribe'] as bool? ?? false,
      unavailableReason: json['unavailableReason'] as String?,
    );
  }
}

class PlatformPlanRepository {
  PlatformPlanRepository(this._dio);

  final Dio _dio;

  Future<PlatformPlanStatus> status() => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/v1/platform-plan');
        return PlatformPlanStatus.fromJson(response.data ?? const {});
      });

  /// Devolve o link do checkout (o preço é definido pelo servidor).
  Future<String> subscribe({required bool yearly}) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/platform-plan/subscribe',
          data: {'interval': yearly ? 'YEARLY' : 'MONTHLY'},
        );
        return response.data!['url'] as String;
      });

  Future<void> cancel() => _guard(() => _dio.post<void>('/api/v1/platform-plan/cancel'));

  Future<void> resume() => _guard(() => _dio.post<void>('/api/v1/platform-plan/resume'));

  Future<String> regularize() => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/v1/platform-plan/regularize');
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
