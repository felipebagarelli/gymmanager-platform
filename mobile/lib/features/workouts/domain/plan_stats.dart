import 'workout.dart';

/// Parte de um grupo muscular no treino (proporcional ao número de séries).
class FocusShare {
  const FocusShare(this.group, this.percent);

  final String group;
  final int percent;
}

/// Números do treino calculados a partir do plano (exercícios, séries, duração, foco).
class PlanStats {
  const PlanStats({
    required this.exercises,
    required this.sets,
    required this.estimatedMinutes,
    required this.focus,
  });

  final int exercises;
  final int sets;
  final int estimatedMinutes;
  final List<FocusShare> focus;

  static const _defaultRestSeconds = 60;
  static const _secondsPerRep = 3;
  static const _setupSecondsPerExercise = 60;

  /// Duração estimada: por série, ~3 s por repetição + o descanso (60 s se não informado);
  /// mais ~1 min por exercício para trocar de aparelho. É só uma estimativa ("~").
  factory PlanStats.from(List<PlanRow> rows) {
    var sets = 0;
    var seconds = 0;
    final setsByGroup = <String, int>{};
    for (final row in rows) {
      final item = row.item;
      sets += item.sets;
      seconds += item.sets * (item.reps * _secondsPerRep + (item.restSeconds ?? _defaultRestSeconds));
      seconds += _setupSecondsPerExercise;
      final group = (row.muscleGroup == null || row.muscleGroup!.trim().isEmpty) ? 'Outros' : row.muscleGroup!.trim();
      setsByGroup[group] = (setsByGroup[group] ?? 0) + item.sets;
    }

    // Percentuais inteiros que somam 100: o resto da divisão vai para os maiores grupos.
    final entries = setsByGroup.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final percents = <String, int>{
      for (final e in entries) e.key: sets == 0 ? 0 : (e.value * 100 ~/ sets),
    };
    var remainder = sets == 0 ? 0 : 100 - percents.values.fold(0, (a, b) => a + b);
    for (final e in entries) {
      if (remainder <= 0) break;
      percents[e.key] = percents[e.key]! + 1;
      remainder--;
    }

    return PlanStats(
      exercises: rows.length,
      sets: sets,
      estimatedMinutes: (seconds / 60).ceil(),
      focus: [for (final e in entries) FocusShare(e.key, percents[e.key]!)],
    );
  }
}
