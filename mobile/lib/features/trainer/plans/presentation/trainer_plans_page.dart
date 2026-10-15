import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/async_widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../billing/application/billing_providers.dart';
import '../../../billing/domain/billing.dart';
import '../../students/application/students_providers.dart';
import '../application/trainer_billing_providers.dart';
import '../data/trainer_billing_repository.dart';
import 'plan_form_sheet.dart';

enum _SubsFilter {
  all('Todas'),
  active('Em dia'),
  overdue('Em atraso'),
  canceled('Canceladas');

  const _SubsFilter(this.label);

  final String label;

  bool matches(Subscription s) => switch (this) {
        _SubsFilter.all => true,
        _SubsFilter.active => s.status == SubscriptionStatus.active,
        _SubsFilter.overdue => s.status == SubscriptionStatus.pastDue,
        _SubsFilter.canceled => s.status == SubscriptionStatus.canceled,
      };
}

/// Aba "Planos" do personal: recebimento, números do mês, planos e assinaturas dos alunos.
class TrainerPlansPage extends ConsumerStatefulWidget {
  const TrainerPlansPage({super.key});

  @override
  ConsumerState<TrainerPlansPage> createState() => _TrainerPlansPageState();
}

class _TrainerPlansPageState extends ConsumerState<TrainerPlansPage> {
  _SubsFilter _filter = _SubsFilter.all;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // o cadastro de recebimento é feito no navegador: ao voltar para o app, confere de novo
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(payoutAccountProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(trainerPlansProvider);
    ref.invalidate(trainerSubscriptionsProvider);
    ref.invalidate(payoutAccountProvider);
    ref.invalidate(tuitionByStudentProvider);
    await ref.read(trainerPlansProvider.future);
  }

  Future<void> _editPlan(Plan? plan, int subscribers) async {
    final draft = await showPlanForm(context, initial: plan, subscribers: subscribers);
    if (draft == null || !mounted) return;
    final repo = ref.read(trainerBillingRepositoryProvider);
    final ok = await runAction(context, () => plan == null ? repo.createPlan(draft) : repo.updatePlan(plan.id, draft));
    if (ok) ref.invalidate(trainerPlansProvider);
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(trainerPlansProvider);
    final subscriptions = ref.watch(trainerSubscriptionsProvider);
    final payout = ref.watch(payoutAccountProvider);
    final current = currentSubscriptions(subscriptions.value ?? const []);
    final summary = BillingSummary.from(current);

    return SafeArea(
      bottom: false,
      child: plans.when(
        loading: () => const SkeletonList(heights: [56, 110, 80, 72, 72]),
        error: (error, _) => ErrorRetry(error: error, onRetry: _refresh),
        data: (planItems) {
          final visibleSubs = [for (final s in current) if (_filter.matches(s)) s];
          final hasActivePlan = planItems.any((p) => p.active);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 24),
              children: [
                Text('PLANOS', style: AppText.display(36).copyWith(letterSpacing: 0.7)),
                Text('Mensalidades dos seus alunos', style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                _PayoutCard(payout: payout, hasActivePlan: hasActivePlan),
                const SizedBox(height: 12),
                _Summary(summary: summary, loading: subscriptions.isLoading && !subscriptions.hasValue, onFilter: (f) => setState(() => _filter = f)),
                const SizedBox(height: 22),
                SectionTitle('Seus planos', action: 'Novo', onAction: () => _editPlan(null, 0)),
                if (planItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nenhum plano ainda. Crie um plano mensal para seus alunos assinarem pelo app.',
                      key: const Key('no-plans'),
                      style: AppText.body(color: AppColors.textMuted),
                    ),
                  )
                else
                  for (final plan in planItems)
                    _PlanTile(
                      plan: plan,
                      subscribers: subscribersOf(plan.id, current),
                      onTap: () => _editPlan(plan, subscribersOf(plan.id, current)),
                    ),
                const SizedBox(height: 22),
                const SectionTitle('Assinaturas'),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final f in _SubsFilter.values) ...[
                        ChoiceChip(
                          key: Key('subs-filter-${f.name}'),
                          label: Text(f.label),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                subscriptions.when(
                  loading: () => const SkeletonBox(height: 72),
                  error: (error, _) => Text(messageOf(error), style: AppText.body(color: AppColors.textMuted)),
                  data: (_) => visibleSubs.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            current.isEmpty ? 'Nenhum aluno assinou ainda.' : 'Nenhuma assinatura neste filtro.',
                            key: const Key('no-subscriptions'),
                            style: AppText.body(color: AppColors.textMuted),
                          ),
                        )
                      : Column(children: [for (final s in visibleSubs) _SubscriptionTile(subscription: s)]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Conta de recebimento no provedor: sem ela os alunos não conseguem assinar.
class _PayoutCard extends ConsumerWidget {
  const _PayoutCard({required this.payout, required this.hasActivePlan});

  final AsyncValue<PayoutAccount> payout;
  final bool hasActivePlan;

  Future<void> _onboard(BuildContext context, WidgetRef ref) async {
    String? url;
    final ok = await runAction(context, () async => url = await ref.read(trainerBillingRepositoryProvider).startOnboarding());
    if (!ok || url == null || !context.mounted) return;
    final opened = await ref.read(urlOpenerProvider)(url!);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o navegador.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return payout.when(
      loading: () => const SkeletonBox(height: 110),
      error: (error, _) => AppCard(
        key: const Key('payout-error'),
        radius: 18,
        child: Row(
          children: [
            const Icon(LucideIcons.circleAlert, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(child: Text(messageOf(error), style: AppText.body(size: 14, color: AppColors.textSecondary))),
            TextButton(onPressed: () => ref.invalidate(payoutAccountProvider), child: const Text('Tentar de novo')),
          ],
        ),
      ),
      data: (account) {
        if (account.chargesEnabled) {
          return AppCard(
            key: const Key('payout-enabled'),
            radius: 18,
            child: Row(
              children: [
                const Icon(LucideIcons.circleCheck, color: AppColors.volt),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recebimentos ativos', style: AppText.body(size: 15.5, weight: FontWeight.w600)),
                      Text('As mensalidades caem na sua conta do Stripe.', style: AppText.body(size: 13, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        final started = account.connected;
        return AppCard(
          key: Key(started ? 'payout-pending' : 'payout-missing'),
          radius: 18,
          borderColor: AppColors.ember,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.wallet, color: AppColors.ember),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(started ? 'Cadastro de recebimento incompleto' : 'Configure o recebimento',
                        style: AppText.body(size: 15.5, weight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                started
                    ? 'Termine o cadastro no Stripe (ou aguarde a análise). Enquanto isso, seus alunos não conseguem assinar.'
                    : 'Para receber as mensalidades, cadastre seus dados no Stripe. ${hasActivePlan ? 'Seus alunos só conseguem assinar depois disso.' : 'Abre no navegador.'}',
                style: AppText.body(size: 13.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      key: const Key('payout-onboard'),
                      label: started ? 'Continuar cadastro' : 'Configurar recebimento',
                      icon: LucideIcons.externalLink,
                      height: 46,
                      onPressed: () => _onboard(context, ref),
                    ),
                  ),
                  if (started) ...[
                    const SizedBox(width: 8),
                    CircleIconButton(
                      key: const Key('payout-refresh'),
                      icon: LucideIcons.refreshCw,
                      tooltip: 'Verificar de novo',
                      onPressed: () => ref.invalidate(payoutAccountProvider),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary, required this.loading, required this.onFilter});

  final BillingSummary summary;
  final bool loading;
  final ValueChanged<_SubsFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    Widget stat(String key, String value, String label, _SubsFilter filter, {Color? color}) => Expanded(
          child: AppCard(
            key: Key(key),
            radius: 16,
            padding: const EdgeInsets.all(12),
            onTap: () => onFilter(filter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loading ? '—' : value, style: AppText.display(30, color: color ?? AppColors.textPrimary)),
                LabelText(label, size: 10),
              ],
            ),
          ),
        );

    return Column(
      children: [
        AppCard(
          key: const Key('monthly-revenue'),
          radius: 18,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LabelText('Receita mensal (em dia)'),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(loading ? '—' : formatPrice(summary.monthlyCents), style: AppText.display(34, color: AppColors.volt)),
                    ),
                    Text('Valor bruto, antes das taxas.', style: AppText.body(size: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            stat('stat-active', '${summary.active}', 'Em dia', _SubsFilter.active),
            const SizedBox(width: 10),
            stat('stat-overdue', '${summary.overdue}', 'Em atraso', _SubsFilter.overdue,
                color: summary.overdue > 0 ? AppColors.ember : null),
            const SizedBox(width: 10),
            stat('stat-canceled', '${summary.canceled}', 'Canceladas', _SubsFilter.canceled),
          ],
        ),
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, required this.subscribers, required this.onTap});

  final Plan plan;
  final int subscribers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        key: Key('plan-${plan.id}'),
        radius: 18,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(plan.name,
                            style: AppText.body(
                              size: 16,
                              weight: FontWeight.w600,
                              color: plan.active ? AppColors.textPrimary : AppColors.textMuted,
                            )),
                      ),
                      if (!plan.active) ...[const SizedBox(width: 8), const TagChip('Desativado')],
                    ],
                  ),
                  if ((plan.description ?? '').trim().isNotEmpty)
                    Text(plan.description!.trim(),
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Text(subscribers == 0 ? 'Nenhum assinante' : (subscribers == 1 ? '1 assinante' : '$subscribers assinantes'),
                      style: AppText.body(size: 12.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatPrice(plan.priceCents), style: AppText.display(24, color: plan.active ? AppColors.volt : AppColors.textMuted)),
                Text('por mês', style: AppText.body(size: 12, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionTile extends ConsumerWidget {
  const _SubscriptionTile({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = subscription;
    final now = ref.watch(clockProvider)();
    final (label, color) = switch (s.status) {
      SubscriptionStatus.active => ('Em dia', AppColors.volt),
      SubscriptionStatus.pastDue => ('Em atraso', AppColors.ember),
      SubscriptionStatus.canceled => ('Cancelada', AppColors.textMuted),
      SubscriptionStatus.pending => ('Aguardando', AppColors.sky),
    };
    final end = s.currentPeriodEnd;
    final period = switch (s.status) {
      SubscriptionStatus.active when end != null => 'Renova em ${formatShortDate(end)}',
      SubscriptionStatus.pastDue => 'Treinos e chat bloqueados até pagar',
      SubscriptionStatus.canceled when end != null && end.isAfter(now) => 'Acesso até ${formatShortDate(end)}',
      _ => null,
    };
    final name = s.studentName ?? 'Aluno';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        key: Key('subscription-${s.id}'),
        radius: 16,
        padding: const EdgeInsets.all(12),
        onTap: s.studentId == null ? null : () => context.push('/trainer/students/${s.studentId}'),
        child: Row(
          children: [
            InitialsAvatar(name: name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppText.body(size: 15, weight: FontWeight.w600)),
                  Text('${s.planName} · ${formatPrice(s.priceCents)}', style: AppText.body(size: 13, color: AppColors.textSecondary)),
                  if (period != null) Text(period, style: AppText.body(size: 12.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            TagChip(label, color: color == AppColors.textMuted ? null : color),
          ],
        ),
      ),
    );
  }
}
