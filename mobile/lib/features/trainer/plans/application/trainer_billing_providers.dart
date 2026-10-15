import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../billing/domain/billing.dart';
import '../data/trainer_billing_repository.dart';

final trainerBillingRepositoryProvider =
    Provider<TrainerBillingRepository>((ref) => TrainerBillingRepository(ref.watch(dioProvider)));

/// Planos do personal, do mais barato ao mais caro (ativos e desativados).
final trainerPlansProvider = FutureProvider<List<Plan>>((ref) async {
  if (ref.watch(currentTrainerProvider) == null) return const [];
  return ref.watch(trainerBillingRepositoryProvider).plans();
});

/// Conta de recebimento. Reconsultada ao voltar do navegador (cadastro no provedor).
final payoutAccountProvider = FutureProvider<PayoutAccount>((ref) async {
  if (ref.watch(currentTrainerProvider) == null) return const PayoutAccount(connected: false, chargesEnabled: false);
  return ref.watch(trainerBillingRepositoryProvider).payoutAccount();
});

/// Assinaturas dos alunos, mais recentes primeiro.
final trainerSubscriptionsProvider = FutureProvider<List<Subscription>>((ref) async {
  if (ref.watch(currentTrainerProvider) == null) return const [];
  return ref.watch(trainerBillingRepositoryProvider).subscriptions();
});

/// Situação atual de cada aluno: vale a assinatura mais recente dele (as antigas são histórico).
List<Subscription> currentSubscriptions(List<Subscription> all) {
  final seen = <int>{};
  final current = <Subscription>[];
  for (final s in all) {
    final key = s.studentId ?? -s.id;
    if (seen.add(key)) current.add(s);
  }
  int rank(SubscriptionStatus status) => switch (status) {
        SubscriptionStatus.pastDue => 0,
        SubscriptionStatus.active => 1,
        SubscriptionStatus.pending => 2,
        SubscriptionStatus.canceled => 3,
      };
  current.sort((a, b) {
    final byStatus = rank(a.status).compareTo(rank(b.status));
    return byStatus != 0 ? byStatus : (a.studentName ?? '').toLowerCase().compareTo((b.studentName ?? '').toLowerCase());
  });
  return current;
}

/// Números do mês a partir das assinaturas atuais.
class BillingSummary {
  const BillingSummary({required this.active, required this.overdue, required this.canceled, required this.monthlyCents});

  factory BillingSummary.from(List<Subscription> current) {
    var active = 0, overdue = 0, canceled = 0, monthly = 0;
    for (final s in current) {
      switch (s.status) {
        case SubscriptionStatus.active:
          active++;
          monthly += s.priceCents;
        case SubscriptionStatus.pastDue:
          overdue++;
        case SubscriptionStatus.canceled:
          canceled++;
        case SubscriptionStatus.pending:
          break;
      }
    }
    return BillingSummary(active: active, overdue: overdue, canceled: canceled, monthlyCents: monthly);
  }

  final int active;
  final int overdue;
  final int canceled;

  /// Soma das mensalidades em dia (valor bruto, antes das taxas do provedor e da plataforma).
  final int monthlyCents;
}

/// Alunos com o plano (assinatura atual em dia ou em atraso).
int subscribersOf(int planId, List<Subscription> current) => current
    .where((s) => s.planId == planId && (s.status == SubscriptionStatus.active || s.status == SubscriptionStatus.pastDue))
    .length;
