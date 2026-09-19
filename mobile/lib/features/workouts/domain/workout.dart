class Workout {
  const Workout({required this.id, required this.name});

  final int id;
  final String name;

  factory Workout.fromJson(Map<String, dynamic> json) =>
      Workout(id: (json['id'] as num).toInt(), name: json['name'] as String);
}

class Exercise {
  const Exercise({required this.id, required this.name, this.muscleGroup});

  final int id;
  final String name;
  final String? muscleGroup;

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        muscleGroup: json['muscleGroup'] as String?,
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
  });

  final int id;
  final int exerciseId;
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
      );
}

/// PlanItem com o nome do exercicio ja resolvido, pronto para a tela.
class PlanRow {
  const PlanRow({required this.item, required this.exerciseName, this.muscleGroup});

  final PlanItem item;
  final String exerciseName;
  final String? muscleGroup;
}
