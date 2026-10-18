class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.email,
    required this.name,
    this.goal,
    this.height,
    this.weight,
    this.weeklyGoal,
    this.hasTrainer = true,
  });

  final int id;
  final String email;
  final String name;
  final String? goal;
  final double? height;
  final double? weight;

  /// Meta de treinos por semana definida pelo personal (null = sem meta).
  final int? weeklyGoal;

  /// Tem vínculo com um personal. Sem personal, o aluno usa o app sozinho (plano da plataforma).
  final bool hasTrainer;

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String,
        name: json['name'] as String,
        goal: json['goal'] as String?,
        height: (json['height'] as num?)?.toDouble(),
        weight: (json['weight'] as num?)?.toDouble(),
        weeklyGoal: (json['weeklyGoal'] as num?)?.toInt(),
        // "status" é o vínculo com o personal: só ativo ou pausado conta (pendente de pagamento, não)
        hasTrainer: json['status'] == 'ACTIVE' || json['status'] == 'PAUSED',
      );
}
