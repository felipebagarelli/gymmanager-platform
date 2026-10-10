import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../../chat/application/chat_providers.dart';
import '../../home/application/home_tab_provider.dart';
import '../application/billing_providers.dart';
import '../domain/billing.dart';

/// Erro 402 da API: acesso bloqueado por mensalidade em atraso.
bool isPaymentRequired(Object error) => error is AppException && error.statusCode == 402;

/// Aluno com a última assinatura em atraso (a API bloqueia treinos e chat nesse caso).
final overdueProvider = Provider<bool>(
  (ref) => ref.watch(mySubscriptionProvider).value?.status == SubscriptionStatus.pastDue,
);

/// Tela de bloqueio no lugar de Treinos e Mensagens enquanto a mensalidade está em atraso.
/// Histórico e Perfil continuam acessíveis pela barra de abas.
class OverdueView extends ConsumerWidget {
  const OverdueView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainer = ref.watch(chatSummaryProvider).value?.trainerName ?? 'seu personal';
    final subscription = ref.watch(mySubscriptionProvider).value;
    final dueDate = subscription?.currentPeriodEnd?.toLocal();

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // brilho laranja ao fundo
          Positioned(
            top: -80,
            left: -60,
            right: -60,
            child: IgnorePointer(
              child: Container(
                height: 380,
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [AppColors.ember.withValues(alpha: 0.18), Colors.transparent], stops: const [0, 0.65]),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.ember.withValues(alpha: 0.12),
                    border: Border.all(color: AppColors.ember.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(LucideIcons.lock, size: 44, color: AppColors.ember),
                ),
                const SizedBox(height: 22),
                Text('MENSALIDADE EM ATRASO',
                    key: const Key('overdue-title'), textAlign: TextAlign.center, style: AppText.display(44).copyWith(height: 0.95)),
                const SizedBox(height: 12),
                Text(
                  'Seus treinos e o chat com $trainer ficam bloqueados até regularizar. Seu histórico continua disponível.',
                  key: const Key('overdue-message'),
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 15, color: AppColors.textSecondary).copyWith(height: 1.45),
                ),
                if (subscription != null) ...[
                  const SizedBox(height: 20),
                  AppCard(
                    radius: 18,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LabelText(subscription.planName),
                              if (dueDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Venceu em ${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}',
                                    style: AppText.body(size: 13.5, color: AppColors.textSecondary),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(formatPrice(subscription.priceCents), style: AppText.display(34)),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                PillButton(
                  key: const Key('overdue-history'),
                  label: 'Ver histórico',
                  style: PillStyle.ghost,
                  onPressed: () => ref.read(homeTabProvider.notifier).select(HomeTab.history),
                ),
                TextButton(
                  key: const Key('overdue-refresh'),
                  onPressed: () => ref.invalidate(mySubscriptionProvider),
                  child: const Text('Já paguei, atualizar'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
