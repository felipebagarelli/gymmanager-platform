import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../sessions/domain/training_stats.dart';

/// Card da semana: sequência em semanas, meta semanal (se o personal definiu) e um
/// círculo por dia (feito / descanso / hoje / futuro).
class WeekCard extends StatelessWidget {
  const WeekCard({super.key, required this.stats, this.weeklyGoal});

  final TrainingStats stats;
  final int? weeklyGoal;

  @override
  Widget build(BuildContext context) {
    final streak = stats.streakWeeks;
    final streakText = streak == 0 ? 'Comece sua sequência' : (streak == 1 ? '1 semana seguida' : '$streak semanas seguidas');

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.flame, size: 18, color: streak == 0 ? AppColors.textMuted : AppColors.ember),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(streakText,
                          key: const Key('streak-text'),
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(weight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              if (weeklyGoal != null)
                Text('Meta · ${stats.sessionsThisWeek} de $weeklyGoal treinos',
                    key: const Key('weekly-goal'),
                    style: AppText.body(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final day in stats.weekDays) _Day(day: day)],
          ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.day});

  final WeekDay day;

  @override
  Widget build(BuildContext context) {
    final state = day.state;
    final done = state == DayState.done;
    final today = state == DayState.today;

    final (Widget? icon, String semantic) = switch (state) {
      DayState.done => (const Icon(LucideIcons.check, size: 18, color: AppColors.onVolt), 'treino feito'),
      DayState.today => (
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.volt, shape: BoxShape.circle)),
          'hoje'
        ),
      DayState.rest => (const Icon(LucideIcons.minus, size: 14, color: AppColors.textMuted), 'descanso'),
      DayState.future => (null, 'a vir'),
    };

    return Semantics(
      label: '${day.label}, $semantic',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(day.label, style: AppText.label(color: today ? AppColors.volt : AppColors.textMuted, size: 11)),
          const SizedBox(height: 8),
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.volt : AppColors.elevated,
              border: today ? Border.all(color: AppColors.volt, width: 2) : null,
            ),
            child: icon,
          ),
        ],
      ),
    );
  }
}
