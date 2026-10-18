import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../billing/application/billing_providers.dart';
import '../../billing/domain/billing.dart';
import '../application/platform_plan_providers.dart';
import '../data/platform_plan_repository.dart';

/// Plano do aluno sem personal: grátis ou GymManager Pro (assinatura pelo Stripe, no navegador).
class PlatformPlanCard extends ConsumerStatefulWidget {
  const PlatformPlanCard({super.key});

  @override
  ConsumerState<PlatformPlanCard> createState() => _PlatformPlanCardState();
}

class _PlatformPlanCardState extends ConsumerState<PlatformPlanCard> {
  late final AppLifecycleListener _lifecycle;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // o pagamento acontece no navegador: ao voltar, confere de novo (quem confirma é o webhook)
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(platformPlanProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    await runAction(context, action);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openCheckout(Future<String> Function() link) => _run(() async {
        final url = await link();
        final opened = await ref.read(urlOpenerProvider)(url);
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir a página de pagamento.')));
        }
        ref.invalidate(platformPlanProvider);
      });

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar o Pro?'),
        content: const Text('Você continua com o Pro até o fim do período já pago. Depois, volta para o plano grátis.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          FilledButton(key: const Key('confirm-cancel-pro'), onPressed: () => Navigator.pop(context, true), child: const Text('Cancelar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await ref.read(platformPlanRepositoryProvider).cancel();
      ref.invalidate(platformPlanProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(platformPlanProvider);
    return plan.when(
      loading: () => const SkeletonBox(height: 180, radius: 20),
      error: (error, _) => AppCard(child: ErrorRetry(error: error, onRetry: () => ref.invalidate(platformPlanProvider))),
      data: (status) {
        if (status == null) return const SizedBox.shrink();
        final repo = ref.read(platformPlanRepositoryProvider);
        return AppCard(
          key: const Key('platform-plan'),
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('GYMMANAGER', style: AppText.display(22)),
                  const SizedBox(width: 8),
                  TagChip(status.isPro ? 'Pro' : 'Grátis', key: const Key('plan-tier'), color: status.isPro ? AppColors.volt : null),
                ],
              ),
              const SizedBox(height: 10),
              if (status.isPro || status.subscription?.status == PlatformSubStatus.pastDue)
                ..._current(status, repo)
              else
                ..._offer(status, repo),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _current(PlatformPlanStatus status, PlatformPlanRepository repo) {
    final sub = status.subscription!;
    final end = sub.currentPeriodEnd;
    final line = switch (sub.status) {
      PlatformSubStatus.trialing when sub.trialEnd != null => 'Teste grátis até ${formatShortDate(sub.trialEnd!)}',
      PlatformSubStatus.pastDue => 'Pagamento pendente: o Pro fica pausado até regularizar.',
      _ when sub.cancelAtPeriodEnd && end != null => 'Cancelado: Pro até ${formatShortDate(end)}',
      _ when end != null => 'Renova em ${formatShortDate(end)}',
      _ => 'Assinatura ativa',
    };
    return [
      Text('${formatPrice(sub.priceCents)}/${sub.yearly ? 'ano' : 'mês'}', style: AppText.body(size: 15.5, weight: FontWeight.w600)),
      Text(line, key: const Key('plan-line'), style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
      const SizedBox(height: 14),
      if (sub.status == PlatformSubStatus.pastDue)
        PillButton(
          key: const Key('plan-regularize'),
          label: 'Pagar agora',
          icon: LucideIcons.creditCard,
          height: 48,
          onPressed: _busy ? null : () => _openCheckout(repo.regularize),
        )
      else if (sub.cancelAtPeriodEnd)
        PillButton(
          key: const Key('plan-resume'),
          label: 'Manter o Pro',
          height: 48,
          onPressed: _busy
              ? null
              : () => _run(() async {
                    await repo.resume();
                    ref.invalidate(platformPlanProvider);
                  }),
        )
      else
        PillButton(
          key: const Key('plan-cancel'),
          label: 'Cancelar assinatura',
          style: PillStyle.ghost,
          height: 46,
          onPressed: _busy ? null : _cancel,
        ),
    ];
  }

  List<Widget> _offer(PlatformPlanStatus status, PlatformPlanRepository repo) {
    final free = status.aiWorkoutsPerMonth ?? 1;
    return [
      Text('Você está no plano grátis: registre seus treinos e gere $free treino com IA por mês.',
          style: AppText.body(size: 14, color: AppColors.textSecondary)),
      const SizedBox(height: 12),
      for (final benefit in const [
        'Treinos montados pela IA sem limite',
        'Ajustes de carga e progressão sugeridos',
        'Tudo do plano grátis',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Icon(LucideIcons.check, size: 16, color: AppColors.volt),
              const SizedBox(width: 8),
              Expanded(child: Text(benefit, style: AppText.body(size: 14))),
            ],
          ),
        ),
      const SizedBox(height: 12),
      if (!status.canSubscribe)
        Text(status.unavailableReason ?? 'Assinatura indisponível no momento.',
            key: const Key('plan-unavailable'), style: AppText.body(size: 13.5, color: AppColors.textMuted))
      else ...[
        if (status.trialAvailable)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${status.trialDays} dias grátis para testar. Cancele quando quiser.',
                key: const Key('plan-trial'), style: AppText.body(size: 13.5, weight: FontWeight.w600, color: AppColors.volt)),
          ),
        PillButton(
          key: const Key('plan-yearly'),
          label: 'Anual · ${formatPrice(status.yearlyCents)}'
              '${status.yearlySavingPercent > 0 ? ' (−${status.yearlySavingPercent}%)' : ''}',
          height: 50,
          onPressed: _busy ? null : () => _openCheckout(() => repo.subscribe(yearly: true)),
        ),
        const SizedBox(height: 8),
        PillButton(
          key: const Key('plan-monthly'),
          label: 'Mensal · ${formatPrice(status.monthlyCents)}',
          style: PillStyle.ghost,
          height: 46,
          onPressed: _busy ? null : () => _openCheckout(() => repo.subscribe(yearly: false)),
        ),
        const SizedBox(height: 6),
        Text('Pagamento seguro pelo Stripe, no navegador. A renovação é automática.',
            textAlign: TextAlign.center, style: AppText.body(size: 12, color: AppColors.textMuted)),
      ],
    ];
  }
}
