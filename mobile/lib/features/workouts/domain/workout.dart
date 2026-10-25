class Workout {
  const Workout({
    required this.id,
    required this.name,
    this.exerciseCount,
    this.studentCount,
    this.trainerId,
    this.weekdays = const [],
  });

  final int id;
  final String name;

  /// Exercícios no plano atual.
  final int? exerciseCount;

  /// Alunos com o treino ativo (só vem para o personal dono do treino).
  final int? studentCount;

  /// Personal que montou; null = treino montado pelo próprio aluno (sem personal).
  final int? trainerId;

  bool get ownedByStudent => trainerId == null;

  /// Dias da semana deste treino para o aluno (1 = segunda ... 7 = domingo). Vazio = sem dia marcado.
  /// Só vem na lista de treinos de um aluno.
  final List<int> weekdays;

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        exerciseCount: (json['exerciseCount'] as num?)?.toInt(),
        studentCount: (json['studentCount'] as num?)?.toInt(),
        trainerId: (json['trainerId'] as num?)?.toInt(),
        weekdays: [for (final d in (json['weekdays'] as List<dynamic>? ?? const [])) (d as num).toInt()],
      );
}

class Exercise {
  const Exercise({required this.id, required this.name, this.muscleGroup, this.trainerId, this.equipment});

  final int id;
  final String name;
  final String? muscleGroup;

  /// Dono do exercício; null = catálogo comum (ninguém altera).
  final int? trainerId;

  /// Exercício criado pelo personal (pode editar e excluir).
  bool get custom => trainerId != null;

  /// Equipamento principal (API: BARBELL, DUMBBELL...); null nos exercícios do personal.
  final String? equipment;

  String? get equipmentLabel => switch (equipment) {
        'BARBELL' => 'Barra',
        'DUMBBELL' => 'Halteres',
        'MACHINE' => 'Máquina',
        'CABLE' => 'Polia',
        'BODYWEIGHT' => 'Peso do corpo',
        'KETTLEBELL' => 'Kettlebell',
        'BAND' => 'Elástico',
        'PULL_UP_BAR' => 'Barra fixa',
        _ => null,
      };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        muscleGroup: json['muscleGroup'] as String?,
        trainerId: (json['trainerId'] as num?)?.toInt(),
        equipment: json['equipment'] as String?,
      );
}

/// Exercicio dentro de um treino (o "planejado").
class PlanItem {
  const PlanItem({
    required this.id,
    required this.exerciseId,
    required this.sets,
    required this.reps,
    this.position,
    this.restSeconds,
    this.targetLoad,
    this.notes,
    this.exerciseName,
    this.muscleGroup,
  });

  final int id;
  final int exerciseId;

  /// Nome e grupo do exercício (o servidor já manda junto).
  final String? exerciseName;
  final String? muscleGroup;
  final int sets;
  final int reps;
  final int? position;
  final int? restSeconds;
  final double? targetLoad;
  final String? notes;

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
        id: (json['id'] as num).toInt(),
        exerciseId: (json['exerciseId'] as num).toInt(),
        sets: (json['sets'] as num).toInt(),
        reps: (json['reps'] as num).toInt(),
        position: (json['position'] as num?)?.toInt(),
        restSeconds: (json['restSeconds'] as num?)?.toInt(),
        targetLoad: (json['targetLoad'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
        exerciseName: json['exerciseName'] as String?,
        muscleGroup: json['muscleGroup'] as String?,
      );
}

/// PlanItem com o nome do exercicio ja resolvido, pronto para a tela.
class PlanRow {
  const PlanRow({required this.item, required this.exerciseName, this.muscleGroup});

  final PlanItem item;
  final String exerciseName;
  final String? muscleGroup;
}
