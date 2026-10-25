import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/routine.dart';
import '../domain/workout.dart';

class WorkoutRepository {
  WorkoutRepository(this._dio);

  final Dio _dio;

  Future<List<Workout>> myWorkouts(int studentId) =>
      _list('/workouts/student/$studentId', Workout.fromJson);

  /// Dias da semana de cada treino do aluno (id → dias). Devolve a lista atualizada.
  Future<List<Workout>> setSchedule(int studentId, Map<int, Set<int>> days) async {
    try {
      final response = await _dio.put<List<dynamic>>('/workouts/student/$studentId/schedule', data: {
        'items': [
          for (final e in days.entries) {'workoutId': e.key, 'weekdays': (e.value.toList()..sort())},
        ],
      });
      return (response.data ?? const []).map((item) => Workout.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  /// Esquema do aluno (dias da semana ou sequência) e o próximo treino da sequência.
  Future<Routine> routine(int studentId) => _routine(() => _dio.get<Map<String, dynamic>>('/workouts/student/$studentId/routine'));

  /// Sequência na ordem de [workoutIds]; [workoutIds] vazio volta para os dias da semana.
  Future<Routine> setRoutine(int studentId, List<int> workoutIds) => _routine(() => _dio.put<Map<String, dynamic>>(
        '/workouts/student/$studentId/routine',
        data: {'mode': workoutIds.isEmpty ? 'WEEKDAYS' : 'ROTATION', 'workoutIds': workoutIds},
      ));

  /// "Pular": escolhe o próximo treino da sequência.
  Future<Routine> skipTo(int studentId, int workoutId) => _routine(() => _dio.post<Map<String, dynamic>>(
        '/workouts/student/$studentId/routine/next',
        data: {'workoutId': workoutId},
      ));

  Future<Routine> _routine(Future<Response<Map<String, dynamic>>> Function() request) async {
    try {
      final response = await request();
      return Routine.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<List<PlanItem>> plan(int workoutId) =>
      _list('/workout-exercises/workout/$workoutId', PlanItem.fromJson);

  Future<List<Exercise>> exercises() => _list('/exercises', Exercise.fromJson);

  Future<List<T>> _list<T>(String path, T Function(Map<String, dynamic>) parse) async {
    try {
      final response = await _dio.get<List<dynamic>>(path);
      return (response.data ?? const [])
          .map((item) => parse(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
