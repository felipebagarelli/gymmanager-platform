import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/onboarding.dart';

/// Onboarding e triagem de saúde do próprio aluno.
class OnboardingRepository {
  OnboardingRepository(this._dio);

  final Dio _dio;

  Future<OnboardingStatus> status() => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/v1/students/me/onboarding');
        return OnboardingStatus.fromJson(response.data ?? const {});
      });

  Future<void> saveTrainingProfile(TrainingProfile profile) =>
      _guard(() => _dio.put<void>('/api/v1/students/me/training-profile', data: profile.toJson()));

  /// O aluno escolhe se o personal pode ver a triagem e o perfil de treino.
  Future<void> setSharing(bool share) =>
      _guard(() => _dio.put<void>('/api/v1/students/me/health-sharing', data: {'share': share}));

  /// Retorna se houve alguma resposta "sim" (risco).
  Future<bool> answerScreening(List<bool> answers) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/students/me/health-screening',
          data: {'answers': answers},
        );
        return response.data?['risk'] as bool? ?? answers.contains(true);
      });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
