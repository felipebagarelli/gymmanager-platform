import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
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
