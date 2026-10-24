import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';

/// Versão vigente dos termos e onde lê-los (null = documento ainda em preparação).
class LegalInfo {
  const LegalInfo({required this.termsVersion, this.termsUrl, this.privacyUrl, this.minimumAge = 12, this.adultAge = 18});

  final String termsVersion;
  final String? termsUrl;
  final String? privacyUrl;
  final int minimumAge;
  final int adultAge;

  factory LegalInfo.fromJson(Map<String, dynamic> json) => LegalInfo(
        termsVersion: json['termsVersion'] as String,
        termsUrl: json['termsUrl'] as String?,
        privacyUrl: json['privacyUrl'] as String?,
        minimumAge: (json['minimumAge'] as num?)?.toInt() ?? 12,
        adultAge: (json['adultAge'] as num?)?.toInt() ?? 18,
      );
}

/// O que a pessoa preenche no cadastro.
class SignupDraft {
  const SignupDraft({
    required this.name,
    required this.email,
    required this.password,
    required this.birthDate,
    required this.termsVersion,
    this.guardianName,
    this.guardianEmail,
  });

  final String name;
  final String email;
  final String password;
  final DateTime birthDate;
  final String termsVersion;
  final String? guardianName;
  final String? guardianEmail;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'birthDate': '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
        'guardianName': guardianName?.trim(),
        'guardianEmail': guardianEmail?.trim(),
        'termsVersion': termsVersion,
        // só chega aqui com as duas caixas marcadas
        'acceptTerms': true,
        'acceptHealthData': true,
      };
}

/// Depois de confirmar o e-mail: falta o responsável autorizar?
class VerifyResult {
  const VerifyResult({required this.guardianPending, this.guardianEmail});

  final bool guardianPending;

  /// Mascarado pelo servidor ("an***@gmail.com").
  final String? guardianEmail;
}

/// Cadastro aberto, confirmação de e-mail e troca de senha (rotas públicas da API).
class AccountRepository {
  AccountRepository(this._dio);

  final Dio _dio;

  /// Exclusão da conta pelo próprio usuário (com a senha). Depois disso o login antigo deixa de valer.
  Future<void> deleteMyAccount(String password) =>
      _guard(() => _dio.post<void>('/api/v1/me/delete', data: {'password': password}));

  /// O aluno corrige os próprios dados.
  Future<void> updateStudentData({required String name, String? phone, double? height, double? weight}) => _guard(
      () => _dio.put<void>('/api/v1/students/me', data: {'name': name, 'phone': phone, 'height': height, 'weight': weight}));

  /// O personal corrige os próprios dados.
  Future<void> updateTrainerData({required String displayName, String? phone}) =>
      _guard(() => _dio.put<void>('/api/v1/trainers/me', data: {'displayName': displayName, 'phone': phone}));

  Future<LegalInfo> legal() => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/v1/legal');
        return LegalInfo.fromJson(response.data!);
      });

  /// Retorna se o cadastro precisa de autorização do responsável (12 a 17 anos).
  Future<bool> register(SignupDraft draft) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/v1/auth/register-student', data: draft.toJson());
        return response.data?['guardianRequired'] as bool? ?? false;
      });

  Future<VerifyResult> verifyEmail(String email, String code) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/auth/verify-email',
          data: {'email': email.trim(), 'code': code.trim()},
        );
        final data = response.data ?? const {};
        return VerifyResult(
          guardianPending: data['guardianPending'] as bool? ?? false,
          guardianEmail: data['guardianEmail'] as String?,
        );
      });

  Future<void> resendVerification(String email) =>
      _guard(() => _dio.post<void>('/api/v1/auth/resend-verification', data: {'email': email.trim()}));

  Future<void> resendGuardian(String email) =>
      _guard(() => _dio.post<void>('/api/v1/auth/resend-guardian', data: {'email': email.trim()}));

  Future<void> forgotPassword(String email) =>
      _guard(() => _dio.post<void>('/api/v1/auth/forgot-password', data: {'email': email.trim()}));

  Future<void> resetPassword(String email, String code, String newPassword) => _guard(() => _dio.post<void>(
        '/api/v1/auth/reset-password',
        data: {'email': email.trim(), 'code': code.trim(), 'newPassword': newPassword},
      ));

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
