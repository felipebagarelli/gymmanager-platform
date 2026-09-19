import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/chat.dart';

class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  Future<List<ConversationSummary>> conversations() => _guard(() async {
        final response = await _dio.get<List<dynamic>>('/api/v1/conversations');
        return [
          for (final item in response.data ?? const [])
            ConversationSummary.fromJson(item as Map<String, dynamic>),
        ];
      });

  /// Sem [after]: as mensagens mais recentes; com [after]: apenas as posteriores (polling).
  Future<List<ChatMessage>> messages(int conversationId, {int? after}) => _guard(() async {
        final response = await _dio.get<List<dynamic>>(
          '/api/v1/conversations/$conversationId/messages',
          queryParameters: {'after': ?after},
        );
        return [
          for (final item in response.data ?? const [])
            ChatMessage.fromJson(item as Map<String, dynamic>),
        ];
      });

  Future<ChatMessage> send(int conversationId, String body) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/conversations/$conversationId/messages',
          data: {'body': body},
        );
        return ChatMessage.fromJson(response.data!);
      });

  Future<void> markRead(int conversationId) =>
      _guard(() => _dio.post<void>('/api/v1/conversations/$conversationId/read'));

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
