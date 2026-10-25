import 'package:dio/dio.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../workouts/domain/workout.dart';
import '../domain/workout_draft.dart';

/// Treinos e biblioteca de exercícios do personal. O servidor confere o dono de cada treino.
class TrainerWorkoutsRepository {
  TrainerWorkoutsRepository(this._dio);

  final Dio _dio;

  // ---------- treinos

  Future<List<Workout>> list() => _list('/workouts', Workout.fromJson);

  Future<Workout> get(int workoutId) => _one(() => _dio.get('/workouts/$workoutId'), Workout.fromJson);

  Future<Workout> create(String name) => _one(() => _dio.post('/workouts', data: {'name': name.trim()}), Workout.fromJson);

  Future<Workout> rename(int workoutId, String name) =>
      _one(() => _dio.put('/workouts/$workoutId', data: {'name': name.trim()}), Workout.fromJson);

  /// Só funciona para treino que nunca foi atribuído (o servidor responde 409 nos outros casos).
  Future<void> delete(int workoutId) => _guard(() => _dio.delete<void>('/workouts/$workoutId'));

  Future<Workout> duplicate(int workoutId) => _one(() => _dio.post('/workouts/$workoutId/duplicate'), Workout.fromJson);

  // ---------- plano (exercícios do treino)

  Future<List<PlanItem>> plan(int workoutId) => _list('/workout-exercises/workout/$workoutId', PlanItem.fromJson);

  /// Sem posição: o servidor coloca no fim do plano.
  Future<PlanItem> addItem(int workoutId, PlanItemDraft draft) =>
      _one(() => _dio.post('/workout-exercises', data: draft.toJson(workoutId)), PlanItem.fromJson);

  Future<PlanItem> updateItem(int itemId, int workoutId, PlanItemDraft draft, {int? position}) => _one(
        () => _dio.put('/workout-exercises/$itemId', data: draft.toJson(workoutId, position: position)),
        PlanItem.fromJson,
      );

  /// Retira o exercício do treino (se o aluno já registrou séries, o histórico continua).
  Future<void> removeItem(int itemId) => _guard(() => _dio.delete<void>('/workout-exercises/$itemId'));

  Future<List<PlanItem>> reorder(int workoutId, List<int> itemIds) => _guard(() async {
        final response = await _dio.put<List<dynamic>>(
          '/workout-exercises/workout/$workoutId/order',
          data: {'workoutExerciseIds': itemIds},
        );
        return [for (final item in response.data ?? const []) PlanItem.fromJson(item as Map<String, dynamic>)];
      });

  // ---------- alunos do treino

  Future<List<WorkoutAssignee>> assignees(int workoutId) =>
      _list('/workouts/$workoutId/assignments', WorkoutAssignee.fromJson);

  Future<void> assign(int workoutId, int studentId) =>
      _guard(() => _dio.post<void>('/workouts/$workoutId/assignments', data: {'studentId': studentId}));

  /// Atribui a vários alunos nos mesmos dias (quem já tem o treino só tem os dias atualizados).
  Future<void> assignBatch(int workoutId, Set<int> studentIds, Set<int> weekdays) => _guard(() => _dio.post<void>(
        '/workouts/$workoutId/assignments/batch',
        data: {'studentIds': studentIds.toList(), 'weekdays': (weekdays.toList()..sort())},
      ));

  Future<void> setWeekdays(int workoutId, int studentId, Set<int> weekdays) => _guard(() => _dio.put<void>(
        '/workouts/$workoutId/assignments/$studentId',
        data: {'weekdays': (weekdays.toList()..sort())},
      ));

  /// A mesma sequência para vários alunos (atribui os treinos que faltarem).
  Future<void> applyRoutine(Set<int> studentIds, List<int> workoutIds) => _guard(() => _dio.post<void>(
        '/workouts/routine/batch',
        data: {'studentIds': studentIds.toList(), 'workoutIds': workoutIds},
      ));

  Future<void> unassign(int workoutId, int studentId) =>
      _guard(() => _dio.delete<void>('/workouts/$workoutId/assignments/$studentId'));

  // ---------- biblioteca de exercícios

  Future<List<Exercise>> exercises() => _list('/exercises', Exercise.fromJson);

  Future<Exercise> createExercise(String name, String muscleGroup) => _one(
        () => _dio.post('/exercises', data: {'name': name.trim(), 'muscleGroup': muscleGroup.trim()}),
        Exercise.fromJson,
      );

  Future<Exercise> updateExercise(int exerciseId, String name, String muscleGroup) => _one(
        () => _dio.put('/exercises/$exerciseId', data: {'name': name.trim(), 'muscleGroup': muscleGroup.trim()}),
        Exercise.fromJson,
      );

  Future<void> deleteExercise(int exerciseId) => _guard(() => _dio.delete<void>('/exercises/$exerciseId'));

  // ---------- auxiliares

  Future<List<T>> _list<T>(String path, T Function(Map<String, dynamic>) parse) => _guard(() async {
        final response = await _dio.get<List<dynamic>>(path);
        return [for (final item in response.data ?? const []) parse(item as Map<String, dynamic>)];
      });

  Future<T> _one<T>(Future<Response<dynamic>> Function() request, T Function(Map<String, dynamic>) parse) =>
      _guard(() async => parse((await request()).data as Map<String, dynamic>));

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
