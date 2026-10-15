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
  FakeChatRepository({List<ChatMessage>? initial, this.canSend = true, this.unread = 0, this.sender = ChatSender.student})
      : messagesStore = [...?initial],
        super(Dio());

  final List<ChatMessage> messagesStore;

  /// Quem envia pelo app nos testes (o aluno, ou o personal no modo personal).
  final ChatSender sender;
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
    final message = msg(_nextId++, sender, body);
    messagesStore.add(message);
    return message;
  }

  @override
  Future<void> markRead(int conversationId) async {
    markReadCalls++;
    unread = 0;
  }
}

/// Conversas do personal: uma por aluno, cada uma com as suas mensagens.
class FakeTrainerChatRepository extends FakeChatRepository {
  FakeTrainerChatRepository(this.summaries, {Map<int, List<ChatMessage>>? messages})
      : store = {for (final e in (messages ?? const {}).entries) e.key: [...e.value]},
        super(sender: ChatSender.trainer);

  List<ConversationSummary> summaries;
  final Map<int, List<ChatMessage>> store;
  final List<int> markedRead = [];
  int conversationsCalls = 0;
  int _next = 2000;

  @override
  Future<List<ConversationSummary>> conversations() async {
    conversationsCalls++;
    return [...summaries];
  }

  @override
  Future<List<ChatMessage>> messages(int conversationId, {int? after}) async => [
        for (final m in store[conversationId] ?? const <ChatMessage>[])
          if (after == null || m.id > after) m,
      ];

  @override
  Future<ChatMessage> send(int conversationId, String body) async {
    if (sendError != null) throw sendError!;
    final message = msg(_next++, ChatSender.trainer, body);
    (store[conversationId] ??= []).add(message);
    return message;
  }

  @override
  Future<void> markRead(int conversationId) async {
    markedRead.add(conversationId);
    summaries = [
      for (final c in summaries)
        c.id == conversationId
            ? ConversationSummary(
                id: c.id,
                trainerName: c.trainerName,
                unreadCount: 0,
                canSend: c.canSend,
                lastMessage: c.lastMessage,
                studentId: c.studentId,
                studentName: c.studentName,
              )
            : c,
    ];
  }
}
