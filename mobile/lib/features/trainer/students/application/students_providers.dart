import '../../../onboarding/domain/onboarding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../sessions/application/session_providers.dart';
import '../../../sessions/domain/workout_session.dart';
import '../../../workouts/application/workout_providers.dart';
import '../../../workouts/domain/workout.dart';
import '../data/students_repository.dart';
import '../domain/managed_student.dart';

final studentsRepositoryProvider = Provider<StudentsRepository>((ref) => StudentsRepository(ref.watch(dioProvider)));

/// Alunos do personal logado (vazio se o usuário não for personal).
final trainerStudentsProvider = FutureProvider<List<ManagedStudent>>((ref) async {
  final trainer = ref.watch(currentTrainerProvider);
  if (trainer == null) return const [];
  final students = await ref.watch(studentsRepositoryProvider).list(trainer.id);
  return [...students]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

/// Mensalidade de cada aluno. Se a cobrança estiver indisponível, a lista de alunos continua funcionando.
final tuitionByStudentProvider = FutureProvider<Map<int, TuitionStatus>>((ref) async {
  if (ref.watch(currentTrainerProvider) == null) return const {};
  try {
    return await ref.watch(studentsRepositoryProvider).tuition();
  } catch (_) {
    return const {};
  }
});

/// Triagem de saúde do aluno, se ele autorizou o personal a ver.
final studentHealthProvider = FutureProvider.autoDispose.family<StudentHealth, int>(
    (ref, studentId) => ref.watch(studentsRepositoryProvider).health(studentId));

final managedStudentProvider = FutureProvider.autoDispose.family<ManagedStudent, int>(
  (ref, studentId) => ref.watch(studentsRepositoryProvider).get(studentId),
);

/// Sessões de um aluno, mais recentes primeiro (mesmo endpoint que o aluno usa).
final studentSessionsProvider = FutureProvider.autoDispose.family<List<WorkoutSession>, int>((ref, studentId) async {
  final sessions = await ref.watch(sessionRepositoryProvider).history(studentId);
  return [...sessions]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
});

/// Treinos atribuídos a um aluno.
final studentWorkoutsProvider = FutureProvider.autoDispose.family<List<Workout>, int>(
  (ref, studentId) => ref.watch(workoutRepositoryProvider).myWorkouts(studentId),
);

/// Recarrega tudo o que depende dos dados de um aluno (depois de criar, editar ou desativar).
void refreshStudent(WidgetRef ref, [int? studentId]) {
  ref.invalidate(trainerStudentsProvider);
  if (studentId != null) ref.invalidate(managedStudentProvider(studentId));
}
