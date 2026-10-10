import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/photo.dart';
import '../domain/assistant.dart';

class AssistantRepository {
  AssistantRepository(this._dio);

  final Dio _dio;

  Future<List<AiMessage>> history() => _guard(() async {
        final response = await _dio.get<List<dynamic>>('/api/v1/ai/messages');
        return [
          for (final item in response.data ?? const []) AiMessage.fromJson(item as Map<String, dynamic>),
        ];
      });

  Future<AiUsage> usage() => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/v1/ai/usage');
        return AiUsage.fromJson(response.data!);
      });

  /// A resposta da IA pode demorar mais que as demais chamadas.
  Future<AiExchange> ask(String question) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/ai/messages',
          data: {'question': question},
          options: Options(receiveTimeout: const Duration(seconds: 90)),
        );
        return AiExchange.fromJson(response.data!);
      });

  /// Pergunta com a foto de um aparelho (texto opcional). A resposta da IA com imagem demora mais.
  Future<AiExchange> askWithPhoto(PickedPhoto photo, {String? question}) => _guard(() async {
        final type = photo.mimeType.split('/');
        final form = FormData.fromMap({
          if (question != null && question.trim().isNotEmpty) 'question': question.trim(),
          'image': MultipartFile.fromBytes(photo.bytes, filename: photo.name, contentType: DioMediaType(type[0], type[1])),
        });
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/ai/messages',
          data: form,
          options: Options(receiveTimeout: const Duration(seconds: 120), sendTimeout: const Duration(seconds: 60)),
        );
        return AiExchange.fromJson(response.data!);
      });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
