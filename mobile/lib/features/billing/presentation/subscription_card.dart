import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../application/billing_providers.dart';
import '../domain/billing.dart';
import 'overdue_view.dart';

String _date(DateTime value) {
  final d = value.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

/// Situação da mensalidade do aluno + escolha de plano / pagamento / cancelamento.
class SubscriptionCard extends ConsumerWidget {
  const SubscriptionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(mySubscriptionProvider);
    return subscription.when(
      loading: () => const SkeletonBox(height: 150, radius: 20),
      error: (error, _) => AppCard(
        child: ErrorRetry(error: error, onRetry: () => ref.invalidate(mySubscriptionProvider)),
      ),
      data: (current) => current == null || current.status == SubscriptionStatus.canceled
          ? const _ChoosePlan()
          : _Current(subscription: current),
    );
  }
}

class _Current extends ConsumerWidget {
  const _Current({required this.subscription});

  final Subscription subscription;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar assinatura?'),
        content: const Text('Você perde o acesso ao acompanhamento do seu personal ao fim do cancelamento.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          FilledButton(
            key: const Key('confirm-cancel'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar assinatura'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(billingRepositoryProvider).cancel();
      ref.invalidate(mySubscriptionProvider);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(messageOf(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (label, color) = switch (subscription.status) {
      SubscriptionStatus.active => ('Ativo', AppColors.success),
      SubscriptionStatus.pastDue => ('Em atraso', AppColors.ember),
      _ => ('Aguardando pagamento', AppColors.sky),
    };
    final end = subscription.currentPeriodEnd;
    final pastDue = subscription.status == SubscriptionStatus.pastDue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('plan-card'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B2410), AppColors.surface],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: pastDue ? AppColors.ember.withValues(alpha: 0.5) : AppColors.mix(AppColors.volt, 0.35, AppColors.borderSubtle),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const LabelText('Meu plano', color: AppColors.volt),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(label,
                          key: const Key('subscription-status'),
                          style: AppText.body(size: 12.5, weight: FontWeight.w700, color: color)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subscription.planName, style: AppText.display(30)),
                        if (end != null)
                          Text('${pastDue ? 'Venceu em' : 'Renova em'} ${_date(end)}',
                              style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatPrice(subscription.priceCents), key: const Key('plan-price'), style: AppText.display(30, color: AppColors.volt)),
                      Text('por mês', style: AppText.body(size: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        if (pastDue) ...[
          const SizedBox(height: 10),
          const InfoAlert(
            key: Key('overdue-notice'),
            kind: AlertKind.warn,
            icon: LucideIcons.lock,
            text: 'Seus treinos e mensagens ficam bloqueados até a regularização do pagamento.',
          ),
          const SizedBox(height: 10),
          const RegularizeButton(),
        ],
        if (subscription.status == SubscriptionStatus.pending)
          TextButton(
            onPressed: () => ref.invalidate(mySubscriptionProvider),
            child: const Text('Já paguei, atualizar'),
          ),
        TextButton(
          key: const Key('cancel-subscription'),
          onPressed: () => _cancel(context, ref),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
          child: const Text('Cancelar assinatura'),
        ),
      ],
    );
  }
}

class _ChoosePlan extends ConsumerWidget {
  const _ChoosePlan();

  Future<void> _subscribe(BuildContext context, WidgetRef ref, Plan plan) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await ref.read(billingRepositoryProvider).subscribe(plan.id);
      final opened = await ref.read(urlOpenerProvider)(url);
      if (!opened) {
        messenger.showSnackBar(const SnackBar(content: Text('Não foi possível abrir a página de pagamento.')));
      }
      ref.invalidate(mySubscriptionProvider);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(messageOf(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(availablePlansProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelText('Assine um plano', color: AppColors.volt),
          const SizedBox(height: 10),
          plans.when(
            loading: () => const SkeletonBox(height: 60),
            error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(availablePlansProvider)),
            data: (items) => items.isEmpty
                ? Text('Seu personal ainda não publicou planos.',
                    key: const Key('no-plans'), style: AppText.body(color: AppColors.textSecondary))
                : Column(
                    children: [
                      for (final plan in items)
                        Padding(
                          key: Key('plan-${plan.id}'),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(plan.name, style: AppText.body(size: 16, weight: FontWeight.w600)),
                                    Text('${formatPrice(plan.priceCents)}/mês',
                                        style: AppText.body(size: 14, color: AppColors.textSecondary)),
                                    if (plan.description != null && plan.description!.isNotEmpty)
                                      Text(plan.description!, style: AppText.body(size: 13, color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              PillButton(
                                key: Key('subscribe-${plan.id}'),
                                label: 'Assinar',
                                height: 44,
                                expand: false,
                                onPressed: () => _subscribe(context, ref, plan),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
