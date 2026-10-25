import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
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
