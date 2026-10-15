import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/student_profile.dart';
import '../domain/trainer_profile.dart';

class LoginResult {
  const LoginResult({
    required this.token,
    required this.expiresInSeconds,
    required this.role,
  });

  final String token;
  final int expiresInSeconds;
  final String role;
}

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<LoginResult> login(String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        loginPath,
        data: {'email': email, 'password': password},
      );
      final data = response.data!;
      return LoginResult(
        token: data['token'] as String,
        expiresInSeconds: (data['expiresInSeconds'] as num).toInt(),
        role: data['role'] as String,
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<StudentProfile> me() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/v1/students/me');
      return StudentProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<TrainerProfile> trainerMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/v1/trainers/me');
      return TrainerProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
