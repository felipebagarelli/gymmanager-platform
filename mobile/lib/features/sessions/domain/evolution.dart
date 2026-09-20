/// Um ponto da evolução de um exercício: o melhor conjunto de uma sessão.
class ProgressPoint {
  const ProgressPoint({required this.date, required this.maxLoadKg, required this.totalReps});

  final DateTime date;
  final double? maxLoadKg;

  /// Soma das repetições de todas as séries daquele exercício na sessão (volume).
  final int totalReps;
}

/// Histórico de um exercício ao longo das sessões, do mais antigo ao mais recente.
class ExerciseProgress {
  const ExerciseProgress({required this.exerciseName, required this.points});

  final String exerciseName;
  final List<ProgressPoint> points;

  bool get hasLoadData => points.any((p) => p.maxLoadKg != null);

  double? get bestLoadKg {
    final loads = [for (final p in points) if (p.maxLoadKg != null) p.maxLoadKg!];
    return loads.isEmpty ? null : loads.reduce((a, b) => a > b ? a : b);
  }

  /// Diferença entre a última e a penúltima marca (positivo = evoluindo).
  double? get lastDeltaKg {
    final loads = [for (final p in points) if (p.maxLoadKg != null) p.maxLoadKg!];
    if (loads.length < 2) return null;
    return loads.last - loads[loads.length - 2];
  }
}
