import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/workout.dart';

class WorkoutRepository {
  WorkoutRepository(this._dio);

  final Dio _dio;

  Future<List<Workout>> myWorkouts(int studentId) =>
      _list('/workouts/student/$studentId', Workout.fromJson);

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
