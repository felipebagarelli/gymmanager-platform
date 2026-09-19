import 'package:dio/dio.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/features/chat/data/chat_repository.dart';
import 'package:gymmanager_mobile/features/chat/domain/chat.dart';

ChatMessage msg(int id, ChatSender sender, String body) => ChatMessage(
      id: id,
      senderRole: sender,
      body: body,
      createdAt: DateTime(2026, 9, 19, 10, id),
    );

class FakeChatRepository extends ChatRepository {
  FakeChatRepository({List<ChatMessage>? initial, this.canSend = true, this.unread = 0})
      : messagesStore = [...?initial],
        super(Dio());

  final List<ChatMessage> messagesStore;
  bool canSend;
  int unread;
  AppException? sendError;
  int markReadCalls = 0;
  final List<int?> afterCursors = [];
  int _nextId = 1000;

  @override
  Future<List<ConversationSummary>> conversations() async => [
        ConversationSummary(
          id: 7,
          trainerName: 'João Personal',
          unreadCount: unread,
          canSend: canSend,
          lastMessage: messagesStore.isEmpty ? null : messagesStore.last,
        ),
      ];

  @override
  Future<List<ChatMessage>> messages(int conversationId, {int? after}) async {
    afterCursors.add(after);
    if (after == null) return [...messagesStore];
    return [
      for (final m in messagesStore)
        if (m.id > after) m,
    ];
  }

  @override
  Future<ChatMessage> send(int conversationId, String body) async {
    if (sendError != null) throw sendError!;
    final message = msg(_nextId++, ChatSender.student, body);
    messagesStore.add(message);
    return message;
  }

  @override
  Future<void> markRead(int conversationId) async {
    markReadCalls++;
    unread = 0;
  }
}
