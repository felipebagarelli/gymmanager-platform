import 'workout_session.dart';

/// Carga que superou o melhor valor anterior daquele exercício.
class NewRecord {
  const NewRecord({required this.exerciseName, required this.loadKg, required this.previousKg});

  final String exerciseName;
  final double loadKg;
  final double previousKg;

  double get gainKg => loadKg - previousKg;
}

/// Resumo exibido em "Treino concluído". Tudo é calculado das séries registradas;
/// nada disso é gravado no banco.
class WorkoutCompletion {
  const WorkoutCompletion({
    required this.workoutId,
    required this.startedAt,
    required this.finishedAt,
    required this.plannedSets,
    required this.doneSets,
    required this.volumeKg,
    required this.averageLoadKg,
    required this.records,
    this.volumeChangePercent,
  });

  final int workoutId;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int plannedSets;
  final int doneSets;

  /// Soma de repetições x carga de todas as séries.
  final double volumeKg;

  /// Carga média ponderada pelas repetições (0 se nenhuma série teve carga).
  final double averageLoadKg;
  final List<NewRecord> records;

  /// Variação do volume em relação ao último treino do mesmo modelo (null se não houver).
  final int? volumeChangePercent;

  Duration get duration => finishedAt.difference(startedAt);

  static double volumeOf(Iterable<Performance> sets) =>
      sets.fold(0.0, (sum, p) => sum + p.reps * (p.loadKg ?? 0));

  /// [session] é a sessão recém-finalizada (com as séries). [history] são as demais
  /// sessões. [exerciseNames] liga cada item do plano ao nome do exercício, para comparar
  /// recordes entre treinos diferentes que usam o mesmo exercício.
  factory WorkoutCompletion.compute({
    required WorkoutSession session,
    required DateTime finishedAt,
    required int plannedSets,
    required List<WorkoutSession> history,
    required Map<int, String> exerciseNames,
  }) {
    final previous = [for (final s in history) if (!s.isOpen && s.id != session.id) s];

    final volume = volumeOf(session.performances);
    final totalReps = session.performances.fold(0, (sum, p) => sum + p.reps);
    final average = (totalReps == 0 || volume == 0) ? 0.0 : volume / totalReps;

    double? bestBefore(String name) {
      double? best;
      for (final s in previous) {
        for (final p in s.performances) {
          if (exerciseNames[p.workoutExerciseId] != name || p.loadKg == null) continue;
          if (best == null || p.loadKg! > best) best = p.loadKg;
        }
      }
      return best;
    }

    // maior carga de cada exercício nesta sessão
    final currentMax = <String, double>{};
    for (final p in session.performances) {
      final name = exerciseNames[p.workoutExerciseId];
      if (name == null || p.loadKg == null) continue;
      if (p.loadKg! > (currentMax[name] ?? -1)) currentMax[name] = p.loadKg!;
    }
    // só há recorde com um valor anterior para comparar (a primeira vez não conta)
    final records = <NewRecord>[
      for (final entry in currentMax.entries)
        if (bestBefore(entry.key) case final before? when entry.value > before)
          NewRecord(exerciseName: entry.key, loadKg: entry.value, previousKg: before),
    ];

    final sameWorkout = [for (final s in previous) if (s.workoutId == session.workoutId) s]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    int? change;
    if (sameWorkout.isNotEmpty) {
      final lastVolume = volumeOf(sameWorkout.first.performances);
      if (lastVolume > 0) change = ((volume / lastVolume - 1) * 100).round();
    }

    return WorkoutCompletion(
      workoutId: session.workoutId,
      startedAt: session.startedAt,
      finishedAt: finishedAt,
      plannedSets: plannedSets,
      doneSets: session.performances.length,
      volumeKg: volume,
      averageLoadKg: average,
      records: records,
      volumeChangePercent: change,
    );
  }
}

/// Última série registrada de um item do plano em sessões já finalizadas
/// (para o texto "última vez 10 × 17,5 kg" do registro de série).
Performance? lastPerformanceOf(List<WorkoutSession> history, int workoutExerciseId, {int? exceptSessionId}) {
  final sessions = [for (final s in history) if (!s.isOpen && s.id != exceptSessionId) s]
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  for (final session in sessions) {
    final sets = session.setsOf(workoutExerciseId);
    if (sets.isNotEmpty) return sets.last;
  }
  return null;
}
