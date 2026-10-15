import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/workout_repository.dart';
import '../domain/plan_stats.dart';
import '../domain/workout.dart';

final workoutRepositoryProvider =
    Provider<WorkoutRepository>((ref) => WorkoutRepository(ref.watch(dioProvider)));

/// Treinos ativamente atribuidos ao aluno logado.
final myWorkoutsProvider = FutureProvider<List<Workout>>((ref) async {
  final profile = ref.watch(currentStudentProvider);
  if (profile == null) return const [];
  return ref.watch(workoutRepositoryProvider).myWorkouts(profile.id);
});

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
