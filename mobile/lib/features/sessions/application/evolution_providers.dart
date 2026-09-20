import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workouts/application/workout_providers.dart';
import '../domain/evolution.dart';
import '../domain/workout_session.dart';
import 'session_providers.dart';

/// Evolução por exercício, calculada a partir do histórico de sessões (finalizadas, mais
/// antigas primeiro). Cruza `workoutExerciseId` das séries com o plano de cada treino
/// (inclusive treinos antigos) para descobrir o nome do exercício.
final evolutionProvider = FutureProvider.autoDispose<List<ExerciseProgress>>((ref) async {
  final sessions = (await ref.watch(historyProvider.future))
      .where((s) => !s.isOpen && s.performances.isNotEmpty)
      .toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  if (sessions.isEmpty) return const [];

  final workoutIds = {for (final s in sessions) s.workoutId};
  final exerciseNameByWorkoutExerciseId = <int, String>{};
  for (final workoutId in workoutIds) {
    final plan = await ref.watch(workoutPlanProvider(workoutId).future);
    for (final row in plan) {
      exerciseNameByWorkoutExerciseId[row.item.id] = row.exerciseName;
    }
  }

  final pointsByExercise = <String, List<ProgressPoint>>{};
  for (final session in sessions) {
    final byExercise = <String, List<Performance>>{};
    for (final performance in session.performances) {
      final name = exerciseNameByWorkoutExerciseId[performance.workoutExerciseId];
      if (name == null) continue; // exercicio removido do plano desde entao
      (byExercise[name] ??= []).add(performance);
    }
    byExercise.forEach((name, performances) {
      final loads = [for (final p in performances) if (p.loadKg != null) p.loadKg!];
      (pointsByExercise[name] ??= []).add(ProgressPoint(
        date: session.startedAt,
        maxLoadKg: loads.isEmpty ? null : loads.reduce((a, b) => a > b ? a : b),
        totalReps: performances.fold(0, (sum, p) => sum + p.reps),
      ));
    });
  }

  final result = [
    for (final entry in pointsByExercise.entries)
      ExerciseProgress(exerciseName: entry.key, points: entry.value),
  ]..sort((a, b) => a.exerciseName.compareTo(b.exerciseName));
  return result;
});
