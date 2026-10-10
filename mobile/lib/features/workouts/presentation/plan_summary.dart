import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/workout.dart';

/// "3 x 10 · 20 kg · descanso 60s" — o que foi planejado para o exercicio.
String describeTarget(PlanItem item) {
  final parts = <String>['${item.sets} x ${item.reps}'];
  if (item.targetLoad != null) parts.add(formatLoad(item.targetLoad));
  if (item.restSeconds != null) parts.add('descanso ${item.restSeconds}s');
  return parts.join(' · ');
}

class PlanRowTile extends StatelessWidget {
  const PlanRowTile({super.key, required this.row});

  final PlanRow row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(row.exerciseName),
        subtitle: Text([
          describeTarget(row.item),
          if (row.item.notes != null) row.item.notes!,
        ].join('\n')),
        isThreeLine: row.item.notes != null,
        trailing: row.muscleGroup == null ? null : Chip(label: Text(row.muscleGroup!)),
      ),
    );
  }
}

/// Exercício numerado do detalhe do treino: nome, meta, observação do personal e tag do grupo.
class ExerciseTile extends StatelessWidget {
  const ExerciseTile({super.key, required this.number, required this.row});

  final int number;
  final PlanRow row;

  @override
  Widget build(BuildContext context) {
    final notes = row.item.notes;
    final group = row.muscleGroup;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        key: Key('exercise-$number'),
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(12)),
              child: Text('$number', style: AppText.display(24, color: AppColors.volt)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.exerciseName, style: AppText.body(size: 17, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(describeTarget(row.item),
                      style: AppText.body(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary)),
                  if (notes != null && notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(LucideIcons.info, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 5),
                        Expanded(child: Text(notes, style: AppText.body(size: 12, color: AppColors.textMuted))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (group != null && group.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              TagChip(group, color: muscleGroupColor(group)),
            ],
          ],
        ),
      ),
    );
  }
}
