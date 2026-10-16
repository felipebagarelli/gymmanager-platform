import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workouts/application/workout_providers.dart';
import '../domain/evolution.dart';
import '../domain/workout_session.dart';
import 'session_providers.dart';

/// Nome do exercício de cada item do plano (`workoutExerciseId`), para todos os treinos que
/// aparecem no histórico, inclusive os antigos. Itens removidos do plano não aparecem.
final exerciseNamesProvider = FutureProvider.autoDispose<Map<int, String>>(
  (ref) async => _exerciseNames(ref, await ref.watch(historyProvider.future)),
);

Future<Map<int, String>> _exerciseNames(Ref ref, List<WorkoutSession> history) async {
  final names = <int, String>{};
  for (final workoutId in {for (final s in history) s.workoutId}) {
    for (final row in await ref.watch(workoutPlanProvider(workoutId).future)) {
      names[row.item.id] = row.exerciseName;
    }
  }
  return names;
}

/// Evolução por exercício, calculada a partir do histórico de sessões (finalizadas, mais
/// antigas primeiro).
final evolutionProvider = FutureProvider.autoDispose<List<ExerciseProgress>>(
  (ref) async => _evolution(ref, await ref.watch(historyProvider.future), () => ref.watch(exerciseNamesProvider.future)),
);

/// Evolução de um aluno visto pelo personal.
final studentEvolutionProvider = FutureProvider.autoDispose.family<List<ExerciseProgress>, int>((ref, studentId) async {
  final history = await ref.watch(studentHistoryProvider(studentId).future);
  return _evolution(ref, history, () => _exerciseNames(ref, history));
});

/// Evolução de quem a tela mostra: o aluno logado ([studentId] nulo) ou um aluno do personal.
FutureProvider<List<ExerciseProgress>> evolutionOf(int? studentId) =>
    studentId == null ? evolutionProvider : studentEvolutionProvider(studentId);

Future<List<ExerciseProgress>> _evolution(
  Ref ref,
  List<WorkoutSession> history,
  Future<Map<int, String>> Function() names,
) async {
  final sessions = history.where((s) => !s.isOpen && s.performances.isNotEmpty).toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  if (sessions.isEmpty) return const [];

  final exerciseNameByWorkoutExerciseId = await names();

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
}
