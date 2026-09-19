enum AiRole { user, assistant }

class AiMessage {
  const AiMessage({required this.id, required this.role, required this.body, required this.createdAt});

  final int id;
  final AiRole role;
  final String body;
  final DateTime createdAt;

  factory AiMessage.fromJson(Map<String, dynamic> json) => AiMessage(
        id: (json['id'] as num).toInt(),
        role: json['role'] == 'ASSISTANT' ? AiRole.assistant : AiRole.user,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class AiExchange {
  const AiExchange({required this.question, required this.answer, required this.remainingToday});

  final AiMessage question;
  final AiMessage answer;
  final int remainingToday;

  factory AiExchange.fromJson(Map<String, dynamic> json) => AiExchange(
        question: AiMessage.fromJson(json['question'] as Map<String, dynamic>),
        answer: AiMessage.fromJson(json['answer'] as Map<String, dynamic>),
        remainingToday: (json['remainingToday'] as num).toInt(),
      );
}

class AiUsage {
  const AiUsage({required this.dailyLimit, required this.usedToday, required this.remainingToday});

  final int dailyLimit;
  final int usedToday;
  final int remainingToday;

  factory AiUsage.fromJson(Map<String, dynamic> json) => AiUsage(
        dailyLimit: (json['dailyLimit'] as num).toInt(),
        usedToday: (json['usedToday'] as num).toInt(),
        remainingToday: (json['remainingToday'] as num).toInt(),
      );
}
