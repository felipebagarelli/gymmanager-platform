import 'package:dio/dio.dart';

import '../../../../core/errors/app_exception.dart';
import '../domain/managed_student.dart';

/// Alunos do personal logado. O servidor confere que o personal é dono do vínculo.
class StudentsRepository {
  StudentsRepository(this._dio);

  final Dio _dio;

  Future<List<ManagedStudent>> list(int trainerId) => _guard(() async {
        final response = await _dio.get<List<dynamic>>('/api/v1/trainers/$trainerId/students');
        return [for (final item in response.data ?? const []) ManagedStudent.fromJson(item as Map<String, dynamic>)];
      });

  Future<ManagedStudent> get(int studentId) => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/v1/students/$studentId');
        return ManagedStudent.fromJson(response.data!);
      });

  /// Cria a conta do aluno (e-mail e senha provisória) já vinculada ao personal.
  Future<ManagedStudent> create(int trainerId, StudentDraft draft, {required String email, required String password}) =>
      _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/trainers/$trainerId/students',
          data: {...draft.toJson(), 'email': email, 'password': password},
        );
        final created = ManagedStudent.fromJson(response.data!);
        // a criação não recebe a meta semanal: grava em seguida, se houver
        final goal = draft.weeklyGoal;
        return goal == null ? created : update(created.id, draft);
      });

  /// Atualiza os dados. Sem meta semanal no rascunho, pede explicitamente para removê-la.
  Future<ManagedStudent> update(int studentId, StudentDraft draft) => _guard(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          '/api/v1/students/$studentId',
          data: {...draft.toJson(), 'weeklyGoal': draft.weeklyGoal, 'clearWeeklyGoal': draft.weeklyGoal == null},
        );
        return ManagedStudent.fromJson(response.data!);
      });

  Future<void> deactivate(int studentId) => _guard(() => _dio.delete<void>('/api/v1/students/$studentId'));

  /// Situação da mensalidade de cada aluno (a mais recente por aluno).
  Future<Map<int, TuitionStatus>> tuition() => _guard(() async {
        final response = await _dio.get<List<dynamic>>('/api/v1/billing/subscriptions');
        final byStudent = <int, TuitionStatus>{};
        // a API devolve as mais recentes primeiro: a primeira de cada aluno é a que vale
        for (final item in response.data ?? const []) {
          final json = item as Map<String, dynamic>;
          final id = (json['studentId'] as num).toInt();
          byStudent.putIfAbsent(id, () => tuitionStatusFrom(json['status'] as String?));
        }
        return byStudent;
      });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
