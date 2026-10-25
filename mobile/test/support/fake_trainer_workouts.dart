import 'package:dio/dio.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/features/trainer/workouts/data/trainer_workouts_repository.dart';
import 'package:gymmanager_mobile/features/trainer/workouts/domain/workout_draft.dart';
import 'package:gymmanager_mobile/features/workouts/domain/workout.dart';

/// Treinos e biblioteca do personal em memória, como o servidor guardaria.
class FakeTrainerWorkoutsRepository extends TrainerWorkoutsRepository {
  FakeTrainerWorkoutsRepository({Map<int, String>? workouts, List<Exercise>? library}) : super(Dio()) {
    names.addAll(workouts ?? {10: 'Treino A - Peito e tríceps', 11: 'Treino B - Pernas'});
    this.library.addAll(library ??
        const [
          Exercise(id: 1, name: 'Supino reto', muscleGroup: 'Peito'),
          Exercise(id: 2, name: 'Agachamento livre', muscleGroup: 'Pernas'),
          Exercise(id: 3, name: 'Tríceps corda', muscleGroup: 'Tríceps', trainerId: 5),
        ]);
    for (final id in names.keys) {
      plans[id] = [];
      assigned[id] = {};
    }
  }

  final Map<int, String> names = {};
  final Map<int, List<PlanItem>> plans = {};
  final Map<int, Map<int, String>> assigned = {};
  final List<Exercise> library = [];

  /// Treinos que já foram de algum aluno (não podem ser excluídos).
  final Set<int> everAssigned = {};
  final calls = <String>[];
  AppException? reorderError;
  int _next = 500;

  static const studentNames = {2: 'Maria Aluna', 3: 'Bruno Silva', 4: 'Carla Souza'};

  Workout _workout(int id) =>
      Workout(id: id, name: names[id]!, exerciseCount: plans[id]!.length, studentCount: assigned[id]!.length);

  Exercise _exercise(int id) => library.firstWhere((e) => e.id == id);

  PlanItem _item(int id, int workoutId, PlanItemDraft d, int? position) {
    final e = _exercise(d.exerciseId);
    return PlanItem(
      id: id,
      exerciseId: d.exerciseId,
      sets: d.sets,
      reps: d.reps,
      position: position,
      restSeconds: d.restSeconds,
      targetLoad: d.targetLoad,
      notes: d.notes,
      exerciseName: e.name,
      muscleGroup: e.muscleGroup,
    );
  }

  /// Coloca exercícios num treino, como se o personal já tivesse montado.
  void seedPlan(int workoutId, List<PlanItemDraft> drafts) {
    for (final d in drafts) {
      plans[workoutId]!.add(_item(_next++, workoutId, d, plans[workoutId]!.length + 1));
    }
  }

  @override
  Future<List<Workout>> list() async {
    calls.add('list');
    final ids = names.keys.toList()..sort((a, b) => names[a]!.compareTo(names[b]!));
    return [for (final id in ids) _workout(id)];
  }

  @override
  Future<Workout> create(String name) async {
    calls.add('create:$name');
    final id = _next++;
    names[id] = name;
    plans[id] = [];
    assigned[id] = {};
    return _workout(id);
  }

  @override
  Future<Workout> rename(int workoutId, String name) async {
    calls.add('rename:$workoutId:$name');
    names[workoutId] = name;
    return _workout(workoutId);
  }

  @override
  Future<void> delete(int workoutId) async {
    calls.add('delete:$workoutId');
    if (everAssigned.contains(workoutId)) {
      throw AppException('Este treino já foi atribuído a alunos; encerre as atribuições em vez de excluí-lo.', statusCode: 409);
    }
    names.remove(workoutId);
  }

  @override
  Future<Workout> duplicate(int workoutId) async {
    calls.add('duplicate:$workoutId');
    final copy = await create('${names[workoutId]} (cópia)');
    seedPlan(copy.id, [for (final i in plans[workoutId]!) PlanItemDraft.fromItem(i)]);
    return _workout(copy.id);
  }

  /// Treinos que alunos do personal montaram (não aparecem na lista dele).
  final Map<int, String> studentOwned = {};

  /// Põe um treino montado pelo aluno, que o personal abre pelo perfil do aluno.
  void seedStudentWorkout(int id, String name) {
    studentOwned[id] = name;
    plans[id] = [];
    assigned[id] = {};
  }

  @override
  Future<Workout> get(int workoutId) async {
    final name = studentOwned[workoutId];
    if (name == null) throw AppException('Treino não encontrado.', statusCode: 404);
    return Workout(id: workoutId, name: name, exerciseCount: plans[workoutId]!.length);
  }

  @override
  Future<List<PlanItem>> plan(int workoutId) async => [...plans[workoutId]!];

  @override
  Future<PlanItem> addItem(int workoutId, PlanItemDraft draft) async {
    calls.add('addItem:$workoutId:${draft.exerciseId}:${draft.sets}x${draft.reps}');
    final item = _item(_next++, workoutId, draft, plans[workoutId]!.length + 1);
    plans[workoutId]!.add(item);
    return item;
  }

  @override
  Future<PlanItem> updateItem(int itemId, int workoutId, PlanItemDraft draft, {int? position}) async {
    calls.add('updateItem:$itemId:${draft.sets}x${draft.reps}:${draft.targetLoad}:${draft.notes}');
    final list = plans[workoutId]!;
    final i = list.indexWhere((p) => p.id == itemId);
    list[i] = _item(itemId, workoutId, draft, position);
    return list[i];
  }

  @override
  Future<void> removeItem(int itemId) async {
    calls.add('removeItem:$itemId');
    for (final list in plans.values) {
      list.removeWhere((p) => p.id == itemId);
    }
  }

  @override
  Future<List<PlanItem>> reorder(int workoutId, List<int> itemIds) async {
    calls.add('reorder:$workoutId:${itemIds.join(',')}');
    if (reorderError != null) throw reorderError!;
    final byId = {for (final p in plans[workoutId]!) p.id: p};
    plans[workoutId] = [for (final id in itemIds) byId[id]!];
    return [...plans[workoutId]!];
  }

  @override
  Future<List<WorkoutAssignee>> assignees(int workoutId) async => [
        for (final e in assigned[workoutId]!.entries)
          WorkoutAssignee(
            studentId: e.key,
            studentName: e.value,
            startedAt: DateTime(2026, 10, 1),
            weekdays: (days['$workoutId:${e.key}'] ?? const <int>{}).toList()..sort(),
          ),
      ];

  /// Dias da semana por atribuição ("treino:aluno").
  final Map<String, Set<int>> days = {};

  @override
  Future<void> assignBatch(int workoutId, Set<int> studentIds, Set<int> weekdays) async {
    calls.add('batch:$workoutId:${(studentIds.toList()..sort()).join(',')}:${(weekdays.toList()..sort()).join(',')}');
    for (final id in studentIds) {
      assigned[workoutId]![id] = studentNames[id] ?? 'Aluno $id';
      days['$workoutId:$id'] = {...weekdays};
    }
    everAssigned.add(workoutId);
  }

  @override
  Future<void> applyRoutine(Set<int> studentIds, List<int> workoutIds) async {
    calls.add('routine:${(studentIds.toList()..sort()).join(',')}:${workoutIds.join(',')}');
  }

  @override
  Future<void> setWeekdays(int workoutId, int studentId, Set<int> weekdays) async {
    calls.add('days:$workoutId:$studentId:${(weekdays.toList()..sort()).join(',')}');
    days['$workoutId:$studentId'] = {...weekdays};
  }

  @override
  Future<void> assign(int workoutId, int studentId) async {
    calls.add('assign:$workoutId:$studentId');
    assigned[workoutId]![studentId] = studentNames[studentId] ?? 'Aluno $studentId';
    everAssigned.add(workoutId);
  }

  @override
  Future<void> unassign(int workoutId, int studentId) async {
    calls.add('unassign:$workoutId:$studentId');
    assigned[workoutId]!.remove(studentId);
  }

  @override
  Future<List<Exercise>> exercises() async => [...library];

  @override
  Future<Exercise> createExercise(String name, String muscleGroup) async {
    calls.add('createExercise:$name:$muscleGroup');
    final e = Exercise(id: _next++, name: name, muscleGroup: muscleGroup, trainerId: 5);
    library.add(e);
    return e;
  }

  @override
  Future<Exercise> updateExercise(int exerciseId, String name, String muscleGroup) async {
    calls.add('updateExercise:$exerciseId:$name:$muscleGroup');
    final i = library.indexWhere((e) => e.id == exerciseId);
    library[i] = Exercise(id: exerciseId, name: name, muscleGroup: muscleGroup, trainerId: 5);
    return library[i];
  }

  @override
  Future<void> deleteExercise(int exerciseId) async {
    calls.add('deleteExercise:$exerciseId');
    library.removeWhere((e) => e.id == exerciseId);
  }
}
