import 'package:dio/dio.dart';

class AppException implements Exception {
  AppException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// Motivo legível por máquina, quando a API manda (ex.: EMAIL_NOT_VERIFIED).
  final String? code;

  /// Converte erros do Dio usando o corpo padronizado da API
  /// ({status, message, timestamp, path}) quando existir.
  factory AppException.fromDio(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return AppException(
        data['message'] as String,
        statusCode: error.response?.statusCode,
        code: data['code'] as String?,
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException('Sem conexão com o servidor. Tente novamente.');
      default:
        return AppException(
          'Não foi possível concluir a operação.',
          statusCode: error.response?.statusCode,
        );
    }
  }

  @override
  String toString() => message;
}
