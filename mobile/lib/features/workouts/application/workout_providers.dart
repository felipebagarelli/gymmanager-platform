import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/workout_repository.dart';
import '../../sessions/application/session_providers.dart';
import '../domain/plan_stats.dart';
import '../domain/routine.dart';
import '../domain/workout.dart';

final workoutRepositoryProvider =
    Provider<WorkoutRepository>((ref) => WorkoutRepository(ref.watch(dioProvider)));

/// Treinos ativamente atribuidos ao aluno logado.
final myWorkoutsProvider = FutureProvider<List<Workout>>((ref) async {
  final profile = ref.watch(currentStudentProvider);
  if (profile == null) return const [];
  return ref.watch(workoutRepositoryProvider).myWorkouts(profile.id);
});

/// Esquema de treino do aluno logado. Relê quando o histórico muda (uma sessão concluída avança a sequência).
/// Se a consulta falhar, segue como dias da semana.
final myRoutineProvider = FutureProvider<Routine>((ref) async {
  final profile = ref.watch(currentStudentProvider);
  if (profile == null) return Routine.weekdays;
  ref.watch(historyProvider);
  try {
    return await ref.watch(workoutRepositoryProvider).routine(profile.id);
  } catch (_) {
    return Routine.weekdays;
  }
});

/// Esquema de treino de um aluno (visão do personal).
final routineProvider = FutureProvider.autoDispose.family<Routine, int>(
    (ref, studentId) => ref.watch(workoutRepositoryProvider).routine(studentId));

final exercisesByIdProvider = FutureProvider<Map<int, Exercise>>((ref) async {
  final exercises = await ref.watch(workoutRepositoryProvider).exercises();
  return {for (final exercise in exercises) exercise.id: exercise};
});

/// Exercicios de um treino, ordenados como o servidor entrega (por posicao).
final workoutPlanProvider = FutureProvider.family<List<PlanRow>, int>((ref, workoutId) async {
  final items = await ref.watch(workoutRepositoryProvider).plan(workoutId);
  final exercises = await ref.watch(exercisesByIdProvider.future);
  return [
    for (final item in items)
      PlanRow(
        item: item,
        exerciseName: exercises[item.exerciseId]?.name ?? 'Exercício #${item.exerciseId}',
        muscleGroup: exercises[item.exerciseId]?.muscleGroup,
      ),
  ];
});

/// Números do treino (exercícios, séries, duração estimada, foco muscular).
final planStatsProvider = FutureProvider.family<PlanStats, int>((ref, workoutId) async {
  return PlanStats.from(await ref.watch(workoutPlanProvider(workoutId).future));
});
