import '../../../../core/utils/formatters.dart';
import '../../../workouts/domain/workout.dart';

/// Valores de um exercício dentro do treino, como o personal preenche no celular.
class PlanItemDraft {
  const PlanItemDraft({
    required this.exerciseId,
    this.sets = 3,
    this.reps = 12,
    this.restSeconds = 60,
    this.targetLoad,
    this.notes,
  });

  factory PlanItemDraft.fromItem(PlanItem item) => PlanItemDraft(
        exerciseId: item.exerciseId,
        sets: item.sets,
        reps: item.reps,
        restSeconds: item.restSeconds,
        targetLoad: item.targetLoad,
        notes: item.notes,
      );

  final int exerciseId;
  final int sets;
  final int reps;
  final int? restSeconds;
  final double? targetLoad;
  final String? notes;

  Map<String, dynamic> toJson(int workoutId, {int? position}) => {
        'exerciseId': exerciseId,
        'workoutId': workoutId,
        'sets': sets,
        'reps': reps,
        'position': position,
        'restSeconds': restSeconds,
        'targetLoad': targetLoad,
        'notes': (notes == null || notes!.trim().isEmpty) ? null : notes!.trim(),
      };
}

/// Aluno com o treino ativo.
class WorkoutAssignee {
  const WorkoutAssignee({required this.studentId, required this.studentName, this.startedAt});

  final int studentId;
  final String studentName;
  final DateTime? startedAt;

  factory WorkoutAssignee.fromJson(Map<String, dynamic> json) => WorkoutAssignee(
        studentId: (json['studentId'] as num).toInt(),
        studentName: json['studentName'] as String? ?? 'Aluno',
        startedAt: json['startedAt'] == null ? null : DateTime.parse(json['startedAt'] as String),
      );
}

/// "3 × 12 · 60 s · 20 kg": resumo do que o aluno vai fazer.
String planItemSummary(PlanItem item) {
  final parts = <String>['${item.sets} × ${item.reps}'];
  if (item.restSeconds != null) parts.add('${item.restSeconds} s');
  if (item.targetLoad != null && item.targetLoad! > 0) {
    parts.add('${formatNumber(item.targetLoad!)} kg');
  }
  return parts.join(' · ');
}

/// Grupos musculares sugeridos ao criar um exercício (os da biblioteca entram junto).
const defaultMuscleGroups = [
  'Peito',
  'Costas',
  'Pernas',
  'Glúteos',
  'Ombros',
  'Bíceps',
  'Tríceps',
  'Abdômen',
  'Panturrilha',
  'Cardio',
];
