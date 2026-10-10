enum AiRole { user, assistant }

/// Pergunta comum ou análise de foto de aparelho (a imagem nunca é guardada: só o texto).
enum AiMessageKind { text, equipmentPhoto }

/// Resposta estruturada da IA para a foto de um aparelho.
class EquipmentAnalysis {
  const EquipmentAnalysis({
    required this.recognized,
    required this.name,
    required this.muscles,
    required this.setup,
    required this.steps,
    required this.inPlan,
  });

  /// Falso quando a IA não reconheceu o aparelho (ela não chuta): o restante vem vazio.
  final bool recognized;
  final String name;
  final List<String> muscles;

  /// "Antes de começar": ajustes de banco, encosto, carga.
  final List<String> setup;
  final List<String> steps;

  /// O aparelho aparece nos treinos ativos do aluno.
  final bool inPlan;

  static List<String> _strings(dynamic value) => [for (final item in (value as List<dynamic>? ?? const [])) item as String];

  factory EquipmentAnalysis.fromJson(Map<String, dynamic> json) => EquipmentAnalysis(
        recognized: json['recognized'] as bool? ?? false,
        name: json['name'] as String? ?? '',
        muscles: _strings(json['muscles']),
        setup: _strings(json['setup']),
        steps: _strings(json['steps']),
        inPlan: json['inPlan'] as bool? ?? false,
      );
}

class AiMessage {
  const AiMessage({
    required this.id,
    required this.role,
    required this.body,
    required this.createdAt,
    this.kind = AiMessageKind.text,
    this.equipment,
  });

  final int id;
  final AiRole role;
  final String body;
  final DateTime createdAt;
  final AiMessageKind kind;

  /// Só nas respostas a uma foto.
  final EquipmentAnalysis? equipment;

  bool get isPhoto => kind == AiMessageKind.equipmentPhoto;

  factory AiMessage.fromJson(Map<String, dynamic> json) => AiMessage(
        id: (json['id'] as num).toInt(),
        role: json['role'] == 'ASSISTANT' ? AiRole.assistant : AiRole.user,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        kind: json['kind'] == 'EQUIPMENT_PHOTO' ? AiMessageKind.equipmentPhoto : AiMessageKind.text,
        equipment: json['equipment'] == null ? null : EquipmentAnalysis.fromJson(json['equipment'] as Map<String, dynamic>),
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
