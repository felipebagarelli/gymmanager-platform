enum ChatSender { trainer, student }

ChatSender _senderFrom(String value) => value == 'TRAINER' ? ChatSender.trainer : ChatSender.student;

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderRole,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final ChatSender senderRole;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: (json['id'] as num).toInt(),
        senderRole: _senderFrom(json['senderRole'] as String),
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.trainerName,
    required this.unreadCount,
    required this.canSend,
    this.lastMessage,
  });

  final int id;
  final String trainerName;
  final int unreadCount;
  final bool canSend;
  final ChatMessage? lastMessage;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) => ConversationSummary(
        id: (json['id'] as num).toInt(),
        trainerName: json['trainerName'] as String? ?? 'Personal',
        unreadCount: (json['unreadCount'] as num).toInt(),
        canSend: json['canSend'] as bool,
        lastMessage: json['lastMessage'] == null
            ? null
            : ChatMessage.fromJson(json['lastMessage'] as Map<String, dynamic>),
      );
}
