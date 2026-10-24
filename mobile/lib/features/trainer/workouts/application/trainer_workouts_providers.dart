import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../workouts/application/workout_providers.dart';
import '../../../workouts/domain/workout.dart';
import '../../students/application/students_providers.dart';
import '../data/trainer_workouts_repository.dart';
import '../domain/workout_draft.dart';

final trainerWorkoutsRepositoryProvider =
    Provider<TrainerWorkoutsRepository>((ref) => TrainerWorkoutsRepository(ref.watch(dioProvider)));

/// Quem monta treinos no app: o personal, ou o aluno sem personal (nos próprios treinos).
bool _buildsWorkouts(Ref ref) {
  if (ref.watch(currentTrainerProvider) != null) return true;
  final student = ref.watch(currentStudentProvider);
  return student != null && !student.hasTrainer;
}

/// Treinos de quem monta (personal, ou aluno sem personal), em ordem alfabética.
final trainerWorkoutsProvider = FutureProvider<List<Workout>>((ref) async {
  if (!_buildsWorkouts(ref)) return const [];
  return ref.watch(trainerWorkoutsRepositoryProvider).list();
});

/// Um treino pelo id: para o personal abrir o treino que o aluno montou (não está na lista dele).
final workoutByIdProvider = FutureProvider.autoDispose.family<Workout, int>(
    (ref, workoutId) => ref.watch(trainerWorkoutsRepositoryProvider).get(workoutId));

/// Biblioteca: catálogo comum + exercícios do personal, em ordem alfabética.
final exerciseLibraryProvider = FutureProvider<List<Exercise>>((ref) async {
  if (!_buildsWorkouts(ref)) return const [];
  final items = await ref.watch(trainerWorkoutsRepositoryProvider).exercises();
  return [...items]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

/// Alunos com um treino ativo.
final workoutAssigneesProvider = FutureProvider.autoDispose.family<List<WorkoutAssignee>, int>(
  (ref, workoutId) => ref.watch(trainerWorkoutsRepositoryProvider).assignees(workoutId),
);

/// Plano de um treino na edição: adicionar, alterar, retirar e reordenar exercícios.
class WorkoutPlanController extends AsyncNotifier<List<PlanItem>> {
  WorkoutPlanController(this.workoutId);

  final int workoutId;

  TrainerWorkoutsRepository get _repository => ref.read(trainerWorkoutsRepositoryProvider);

  @override
  Future<List<PlanItem>> build() => _repository.plan(workoutId);

  Future<void> add(PlanItemDraft draft) async {
    final item = await _repository.addItem(workoutId, draft);
    state = AsyncData([...state.value ?? const [], item]);
    _changed();
  }

  Future<void> edit(PlanItem item, PlanItemDraft draft) async {
    final updated = await _repository.updateItem(item.id, workoutId, draft, position: item.position);
    state = AsyncData([for (final i in state.value ?? const <PlanItem>[]) i.id == item.id ? updated : i]);
    _changed();
  }

  Future<void> remove(PlanItem item) async {
    await _repository.removeItem(item.id);
    state = AsyncData([for (final i in state.value ?? const <PlanItem>[]) if (i.id != item.id) i]);
    _changed();
  }

  /// Move o exercício de [oldIndex] para a posição final [newIndex]. A lista muda na hora;
  /// se o servidor recusar, volta à ordem anterior e o erro sobe para a tela.
  Future<void> move(int oldIndex, int newIndex) async {
    final before = state.value ?? const <PlanItem>[];
    if (oldIndex < 0 || oldIndex >= before.length) return;
    final target = newIndex.clamp(0, before.length - 1);
    if (target == oldIndex) return;
    final next = [...before];
    next.insert(target, next.removeAt(oldIndex));
    state = AsyncData(next);
    try {
      final saved = await _repository.reorder(workoutId, [for (final i in next) i.id]);
      state = AsyncData(saved);
      _changed();
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }

  /// O número de exercícios aparece na lista de treinos; no aluno sem personal, a tela de
  /// execução usa o mesmo plano.
  void _changed() {
    ref.invalidate(trainerWorkoutsProvider);
    ref.invalidate(workoutPlanProvider(workoutId));
    ref.invalidate(myWorkoutsProvider);
  }
}

final workoutPlanEditorProvider = AsyncNotifierProvider.autoDispose
    .family<WorkoutPlanController, List<PlanItem>, int>(WorkoutPlanController.new);

/// Depois de atribuir ou retirar um treino de um aluno: atualiza contagens, o treino e o perfil do aluno.
void refreshAssignments(WidgetRef ref, {required int workoutId, int? studentId}) {
  ref.invalidate(trainerWorkoutsProvider);
  ref.invalidate(workoutAssigneesProvider(workoutId));
  if (studentId != null) ref.invalidate(studentWorkoutsProvider(studentId));
}
