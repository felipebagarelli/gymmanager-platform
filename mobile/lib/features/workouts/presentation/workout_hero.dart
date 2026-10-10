import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../../sessions/domain/workout_session.dart';
import '../domain/plan_stats.dart';
import '../domain/workout_name.dart';

/// Resumo "3 exercícios · 9 séries · ~18 min".
String describePlan(PlanStats? stats) {
  if (stats == null) return '';
  return '${stats.exercises} ${stats.exercises == 1 ? 'exercício' : 'exercícios'}'
      ' · ${stats.sets} ${stats.sets == 1 ? 'série' : 'séries'}'
      ' · ~${stats.estimatedMinutes} min';
}

/// Tamanho do título conforme o comprimento, para nomes longos não estourarem a largura.
double _heroTitleSize(String title) => title.length <= 12 ? 60 : (title.length <= 20 ? 46 : 36);

/// Card em destaque (gradiente volt) com o treino sugerido para hoje.
class WorkoutHero extends StatelessWidget {
  const WorkoutHero({super.key, required this.name, required this.stats, required this.onStart});

  final String name;
  final PlanStats? stats;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final parts = splitWorkoutName(name);
    final summary = [if (parts.tag != null) parts.tag!, if (stats != null) describePlan(stats)].join(' · ');

    return Container(
      key: const Key('workout-hero'),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(24)),
      child: Stack(
        children: [
          // halter decorativo ao fundo, sem significado para leitores de tela
          Positioned(
            right: -34,
            top: -28,
            child: ExcludeSemantics(
              child: Icon(LucideIcons.dumbbell, size: 190, color: AppColors.onVolt.withValues(alpha: 0.13)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.onVolt, borderRadius: BorderRadius.circular(99)),
                child: Text('TREINO DE HOJE',
                    style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.volt).copyWith(letterSpacing: 1)),
              ),
              const SizedBox(height: 12),
              Text(
                parts.title.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(_heroTitleSize(parts.title), color: AppColors.onVolt, weight: FontWeight.w800)
                    .copyWith(height: 0.95),
              ),
              const SizedBox(height: 10),
              Text(summary,
                  style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.onVolt.withValues(alpha: 0.75))),
              const SizedBox(height: 16),
              PillButton(
                key: const Key('hero-start'),
                label: 'Iniciar treino',
                icon: LucideIcons.play,
                style: PillStyle.dark,
                onPressed: onStart,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Substitui o hero depois que o aluno treinou hoje: mostra o resumo da sessão.
class TodayDoneCard extends StatelessWidget {
  const TodayDoneCard({super.key, required this.workoutName, required this.session});

  final String workoutName;
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final parts = splitWorkoutName(workoutName);
    final finished = session.finishedAt!;
    final volume = session.performances.fold<double>(0, (sum, p) => sum + p.reps * (p.loadKg ?? 0));
    final seconds = finished.difference(session.startedAt).inSeconds;

    return AppCard(
      key: const Key('today-done-card'),
      child: SizedBox(
        width: double.infinity,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelText('Treino de hoje concluído', color: AppColors.success),
          const SizedBox(height: 10),
          Text(parts.title.toUpperCase(), style: AppText.display(40)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            children: [
              Text(formatClock(seconds), style: AppText.body(weight: FontWeight.w500, color: AppColors.textSecondary)),
              Text('${session.performances.length} séries',
                  style: AppText.body(weight: FontWeight.w500, color: AppColors.textSecondary)),
              if (volume > 0)
                Text('${formatNumber(volume)} kg',
                    style: AppText.body(weight: FontWeight.w500, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
