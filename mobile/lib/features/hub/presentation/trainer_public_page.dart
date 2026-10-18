import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../../billing/application/billing_providers.dart';
import '../../billing/domain/billing.dart';
import '../application/hub_providers.dart';

/// Perfil de um personal no hub: quem é, como atende e os planos. "Assinar" abre o pagamento; o
/// vínculo só começa quando o pagamento é confirmado.
class TrainerPublicPage extends ConsumerStatefulWidget {
  const TrainerPublicPage({super.key, required this.trainerId});

  final int trainerId;

  @override
  ConsumerState<TrainerPublicPage> createState() => _TrainerPublicPageState();
}

class _TrainerPublicPageState extends ConsumerState<TrainerPublicPage> {
  late final AppLifecycleListener _lifecycle;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // o pagamento acontece no navegador: ao voltar, confere se o vínculo já começou
    _lifecycle = AppLifecycleListener(onResume: _checkHired);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _checkHired() async {
    await ref.read(authControllerProvider.notifier).refreshUser();
    if (!mounted) return;
    if (ref.read(currentStudentProvider)?.hasTrainer ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pagamento confirmado! Agora você treina com seu personal.')));
      context.go('/');
    }
  }

  Future<void> _hire(Plan plan) async {
    setState(() => _busy = true);
    await runAction(context, () async {
      final url = await ref.read(hubRepositoryProvider).hire(widget.trainerId, plan.id);
      final opened = await ref.read(urlOpenerProvider)(url);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir a página de pagamento.')));
      }
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(trainerDetailProvider(widget.trainerId));
    return Scaffold(
      body: SafeArea(
        child: detail.when(
          loading: () => const SkeletonList(heights: [56, 120, 90, 90]),
          error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(trainerDetailProvider(widget.trainerId))),
          data: (d) {
            final t = d.card;
            return ListView(
              padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: CircleIconButton(
                    icon: LucideIcons.arrowLeft,
                    tooltip: 'Voltar',
                    onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    InitialsAvatar(name: t.displayName, size: 64),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.displayName.toUpperCase(), key: const Key('hub-trainer-name'), style: AppText.display(28)),
                          Text(t.place, style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                if ((t.headline ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(t.headline!, style: AppText.body(size: 16, weight: FontWeight.w600)),
                ],
                if (t.specialties.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final s in t.specialties) TagChip(s.label)]),
                ],
                if ((d.bio ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(d.bio!.trim(), style: AppText.body(size: 14.5, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 20),
                const SectionTitle('Planos'),
                for (final plan in d.plans)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      key: Key('hub-plan-${plan.id}'),
                      radius: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(plan.name, style: AppText.body(size: 16, weight: FontWeight.w600))),
                              Text('${formatPrice(plan.priceCents)}/mês', style: AppText.display(20, color: AppColors.volt)),
                            ],
                          ),
                          if ((plan.description ?? '').trim().isNotEmpty)
                            Text(plan.description!.trim(), style: AppText.body(size: 13.5, color: AppColors.textMuted)),
                          const SizedBox(height: 10),
                          PillButton(
                            key: Key('hub-hire-${plan.id}'),
                            label: 'Assinar',
                            height: 46,
                            onPressed: _busy ? null : () => _hire(plan),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'O pagamento é feito pelo Stripe, no navegador. Seu acompanhamento começa assim que ele for confirmado. '
                  'Seus treinos e seu histórico continuam no app.',
                  key: const Key('hub-hire-note'),
                  style: AppText.body(size: 12.5, color: AppColors.textMuted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
