import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_widgets.dart';
import '../application/billing_providers.dart';
import '../domain/billing.dart';

/// Situacao da mensalidade do aluno + escolha de plano / pagamento / cancelamento.
class SubscriptionCard extends ConsumerWidget {
  const SubscriptionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(mySubscriptionProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: subscription.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(mySubscriptionProvider)),
          data: (current) => current == null || current.status == SubscriptionStatus.canceled
              ? const _ChoosePlan()
              : _Current(subscription: current),
        ),
      ),
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
    final (label, color, icon) = switch (subscription.status) {
      SubscriptionStatus.active => ('Em dia', Colors.green, Icons.check_circle),
      SubscriptionStatus.pastDue => ('Em atraso', Colors.red, Icons.warning_amber),
      _ => ('Aguardando pagamento', Colors.orange, Icons.hourglass_top),
    };
    final end = subscription.currentPeriodEnd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Minha assinatura', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('${subscription.planName} · ${formatPrice(subscription.priceCents)}/mês'),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label, key: const Key('subscription-status'), style: TextStyle(color: color)),
          ],
        ),
        if (end != null)
          Text('Próxima cobrança: ${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}',
              style: Theme.of(context).textTheme.bodySmall),
        if (subscription.status == SubscriptionStatus.pastDue)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Seus treinos e mensagens ficam bloqueados até a regularização do pagamento.',
              key: Key('overdue-notice'),
            ),
          ),
        if (subscription.status == SubscriptionStatus.pending)
          TextButton(
            onPressed: () => ref.invalidate(mySubscriptionProvider),
            child: const Text('Já paguei, atualizar'),
          ),
        TextButton(
          key: const Key('cancel-subscription'),
          onPressed: () => _cancel(context, ref),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Assine um plano', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        plans.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(availablePlansProvider)),
          data: (items) => items.isEmpty
              ? const Text('Seu personal ainda não publicou planos.', key: Key('no-plans'))
              : Column(
                  children: [
                    for (final plan in items)
                      ListTile(
                        key: Key('plan-${plan.id}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(plan.name),
                        subtitle: Text('${formatPrice(plan.priceCents)}/mês'
                            '${plan.description == null || plan.description!.isEmpty ? '' : '\n${plan.description}'}'),
                        trailing: FilledButton(
                          key: Key('subscribe-${plan.id}'),
                          onPressed: () => _subscribe(context, ref, plan),
                          child: const Text('Assinar'),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
