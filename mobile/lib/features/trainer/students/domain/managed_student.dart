/// Situação do vínculo personal/aluno, como o servidor devolve.
enum LinkStatus {
  invited('INVITED'),
  active('ACTIVE'),
  paused('PAUSED'),
  canceled('CANCELED');

  const LinkStatus(this.api);

  final String api;

  static LinkStatus? fromApi(String? value) {
    for (final status in LinkStatus.values) {
      if (status.api == value) return status;
    }
    return null;
  }
}

/// Aluno visto pelo personal (`StudentProfileResponse` da API).
class ManagedStudent {
  const ManagedStudent({
    required this.id,
    required this.email,
    required this.name,
    required this.active,
    this.birthDate,
    this.phone,
    this.goal,
    this.height,
    this.weight,
    this.linkStatus,
    this.weeklyGoal,
    this.lastWorkoutAt,
  });

  final int id;
  final String email;
  final String name;

  /// Falso depois que o personal desativa o aluno.
  final bool active;
  final DateTime? birthDate;
  final String? phone;
  final String? goal;

  /// Altura em metros.
  final double? height;

  /// Peso em kg.
  final double? weight;
  final LinkStatus? linkStatus;

  /// Meta de treinos por semana (null = sem meta).
  final int? weeklyGoal;

  /// Início do último treino finalizado (null = nunca treinou).
  final DateTime? lastWorkoutAt;

  factory ManagedStudent.fromJson(Map<String, dynamic> json) => ManagedStudent(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String,
        name: json['name'] as String,
        active: json['active'] as bool? ?? true,
        birthDate: json['birthDate'] == null ? null : DateTime.parse(json['birthDate'] as String),
        phone: json['phone'] as String?,
        goal: json['goal'] as String?,
        height: (json['height'] as num?)?.toDouble(),
        weight: (json['weight'] as num?)?.toDouble(),
        linkStatus: LinkStatus.fromApi(json['status'] as String?),
        weeklyGoal: (json['weeklyGoal'] as num?)?.toInt(),
        lastWorkoutAt: json['lastWorkoutAt'] == null ? null : DateTime.parse(json['lastWorkoutAt'] as String),
      );
}

/// Dados que o personal preenche ao cadastrar ou editar um aluno.
class StudentDraft {
  const StudentDraft({
    required this.name,
    this.birthDate,
    this.phone,
    this.goal,
    this.height,
    this.weight,
    this.weeklyGoal,
  });

  final String name;
  final DateTime? birthDate;
  final String? phone;
  final String? goal;
  final double? height;
  final double? weight;
  final int? weeklyGoal;

  static String? _date(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'name': name,
        'birthDate': _date(birthDate),
        'phone': phone,
        'goal': goal,
        'height': height,
        'weight': weight,
      };
}

/// Situação da mensalidade de um aluno (vista pelo personal).
enum TuitionStatus { upToDate, overdue, pending, none }

TuitionStatus tuitionStatusFrom(String? api) => switch (api) {
      'ACTIVE' => TuitionStatus.upToDate,
      'PAST_DUE' => TuitionStatus.overdue,
      'PENDING' => TuitionStatus.pending,
      _ => TuitionStatus.none,
    };
