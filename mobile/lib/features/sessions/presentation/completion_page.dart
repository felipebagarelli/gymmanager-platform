import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../../home/application/home_tab_provider.dart';
import '../../workouts/application/workout_providers.dart';
import '../../workouts/domain/workout_name.dart';
import '../application/session_providers.dart';
import '../domain/completion.dart';

/// "Treino concluído": resumo da sessão que acabou de ser finalizada (tela de fluxo, sem tab bar).
class CompletionPage extends ConsumerWidget {
  const CompletionPage({super.key, required this.workoutId});

  final int workoutId;

  void _goHome(BuildContext context, WidgetRef ref, {bool evolution = false}) {
    ref.read(completedWorkoutProvider.notifier).set(null);
    ref.read(homeTabProvider.notifier).select(evolution ? HomeTab.history : HomeTab.workouts);
    if (evolution) ref.read(historySubTabProvider.notifier).select(1);
    context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completion = ref.watch(completedWorkoutProvider);
    if (completion == null || completion.workoutId != workoutId) {
      // abriu sem um treino recém-finalizado (ex.: app reaberto): não há o que mostrar
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/');
      });
      return const Scaffold();
    }

    final name = ref.watch(myWorkoutsProvider).value?.where((w) => w.id == workoutId).firstOrNull?.name;
    final parts = splitWorkoutName(name ?? 'Treino');
    final date = completion.finishedAt.toLocal();
    final subtitle = [
      if (parts.tag != null) parts.tag!,
      parts.title,
      formatShortDate(date),
    ].join(' · ');

    return PopScope(
      canPop: false,
      // o "voltar" do sistema leva ao início, não de volta à execução já finalizada
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome(context, ref);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(kScreenPadding, 28, kScreenPadding, 16),
                  children: [
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(color: AppColors.volt, shape: BoxShape.circle),
                        child: const Icon(LucideIcons.check, size: 48, color: AppColors.onVolt),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('TREINO CONCLUÍDO',
                        textAlign: TextAlign.center, style: AppText.display(46, weight: FontWeight.w800).copyWith(height: 0.95)),
                    const SizedBox(height: 8),
                    Text(subtitle, textAlign: TextAlign.center, style: AppText.body(color: AppColors.textSecondary)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _Kpi(value: formatClock(completion.duration.inSeconds), label: 'Tempo', valueKey: const Key('kpi-time'))),
                        const SizedBox(width: 10),
                        Expanded(child: _Kpi(value: formatNumber(completion.volumeKg), unit: 'kg', label: 'Volume', valueKey: const Key('kpi-volume'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _Kpi(value: '${completion.doneSets}/${completion.plannedSets}', label: 'Séries', valueKey: const Key('kpi-sets'))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Kpi(
                            value: completion.averageLoadKg == 0 ? '—' : formatNumber((completion.averageLoadKg * 10).round() / 10),
                            unit: completion.averageLoadKg == 0 ? null : 'kg',
                            label: 'Carga média',
                            valueKey: const Key('kpi-average'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (completion.records.isNotEmpty)
                      _RecordsCard(records: completion.records)
                    else if (completion.volumeChangePercent != null)
                      _VolumeChange(percent: completion.volumeChangePercent!),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 16),
                child: Column(
                  children: [
                    PillButton(
                      key: const Key('see-evolution'),
                      label: 'Ver evolução',
                      onPressed: () => _goHome(context, ref, evolution: true),
                    ),
                    const SizedBox(height: 10),
                    PillButton(
                      key: const Key('back-home'),
                      label: 'Voltar ao início',
                      style: PillStyle.ghost,
                      height: 46,
                      onPressed: () => _goHome(context, ref),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label, required this.valueKey, this.unit});

  final String value;
  final String? unit;
  final String label;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: value, style: AppText.display(40)),
                if (unit != null) TextSpan(text: ' $unit', style: AppText.display(18)),
              ]),
              key: valueKey,
            ),
          ),
          const SizedBox(height: 4),
          LabelText(label),
        ],
      ),
    );
  }
}

class _RecordsCard extends StatelessWidget {
  const _RecordsCard({required this.records});

  final List<NewRecord> records;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('records-card'),
      radius: 16,
      padding: const EdgeInsets.all(14),
      color: AppColors.mix(AppColors.volt, 0.07),
      borderColor: AppColors.mix(AppColors.volt, 0.45, AppColors.borderSubtle),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.trophy, size: 28, color: AppColors.volt),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LabelText('Novo recorde', color: AppColors.volt),
                for (final record in records)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                          text: '${record.exerciseName} · ${formatNumber(record.loadKg)} kg  ',
                          style: AppText.body(size: 16, weight: FontWeight.w600)),
                      TextSpan(
                          text: '+${formatNumber(record.gainKg)} kg',
                          style: AppText.body(size: 13, color: AppColors.success)),
                    ])),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeChange extends StatelessWidget {
  const _VolumeChange({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final up = percent >= 0;
    return InfoAlert(
      key: const Key('volume-change'),
      kind: up ? AlertKind.good : AlertKind.warn,
      icon: LucideIcons.trendingUp,
      text: 'Volume ${up ? '+' : ''}$percent% em relação ao último treino',
    );
  }
}
