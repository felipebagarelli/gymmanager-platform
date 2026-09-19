import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/workout_session.dart';

class SessionRepository {
  SessionRepository(this._dio);

  final Dio _dio;

  Future<List<WorkoutSession>> history(int studentId) => _guard(() async {
        final response =
            await _dio.get<List<dynamic>>('/api/v1/students/$studentId/workout-sessions');
        return [
          for (final item in response.data ?? const [])
            WorkoutSession.fromJson(item as Map<String, dynamic>),
        ];
      });

  Future<WorkoutSession> get(int sessionId) => _guard(() async {
        final response =
            await _dio.get<Map<String, dynamic>>('/api/v1/workout-sessions/$sessionId');
        return WorkoutSession.fromJson(response.data!);
      });

  Future<WorkoutSession> start(int workoutId) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/workout-sessions',
          data: {'workoutId': workoutId},
        );
        return WorkoutSession.fromJson(response.data!);
      });

  Future<void> addPerformance(
    int sessionId, {
    required int workoutExerciseId,
    required int setNumber,
    required int reps,
    double? loadKg,
  }) =>
      _guard(() => _dio.post<void>(
            '/api/v1/workout-sessions/$sessionId/performances',
            data: {
              'workoutExerciseId': workoutExerciseId,
              'setNumber': setNumber,
              'reps': reps,
              'loadKg': loadKg,
            },
          ));

  Future<void> updatePerformance(
    int sessionId,
    int performanceId, {
    required int setNumber,
    required int reps,
    double? loadKg,
  }) =>
      _guard(() => _dio.put<void>(
            '/api/v1/workout-sessions/$sessionId/performances/$performanceId',
            data: {'setNumber': setNumber, 'reps': reps, 'loadKg': loadKg},
          ));

  Future<void> deletePerformance(int sessionId, int performanceId) => _guard(() =>
      _dio.delete<void>('/api/v1/workout-sessions/$sessionId/performances/$performanceId'));

  Future<void> finish(int sessionId) =>
      _guard(() => _dio.post<void>('/api/v1/workout-sessions/$sessionId/finish'));

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
