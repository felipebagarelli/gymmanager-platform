class Performance {
  const Performance({
    required this.id,
    required this.workoutExerciseId,
    required this.setNumber,
    required this.reps,
    this.loadKg,
  });

  final int id;
  final int workoutExerciseId;
  final int setNumber;
  final int reps;
  final double? loadKg;

  factory Performance.fromJson(Map<String, dynamic> json) => Performance(
        id: (json['id'] as num).toInt(),
        workoutExerciseId: (json['workoutExerciseId'] as num).toInt(),
        setNumber: (json['setNumber'] as num).toInt(),
        reps: (json['reps'] as num).toInt(),
        loadKg: (json['loadKg'] as num?)?.toDouble(),
      );
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.workoutId,
    required this.startedAt,
    this.finishedAt,
    this.performances = const [],
  });

  final int id;
  final int workoutId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<Performance> performances;

  bool get isOpen => finishedAt == null;

  List<Performance> setsOf(int workoutExerciseId) => [
        for (final p in performances)
          if (p.workoutExerciseId == workoutExerciseId) p,
      ]..sort((a, b) => a.setNumber.compareTo(b.setNumber));

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
        id: (json['id'] as num).toInt(),
        workoutId: (json['workoutId'] as num).toInt(),
        startedAt: DateTime.parse(json['startedAt'] as String),
        finishedAt: json['finishedAt'] == null ? null : DateTime.parse(json['finishedAt'] as String),
        performances: [
          for (final item in (json['performances'] as List<dynamic>? ?? const []))
            Performance.fromJson(item as Map<String, dynamic>),
        ],
      );
}
