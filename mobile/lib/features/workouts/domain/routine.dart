/// Esquema de treino do aluno: dias da semana ou sequência (AB, ABC...).
class Routine {
  const Routine({required this.rotation, this.sequence = const [], this.nextWorkoutId});

  /// true = sequência: o próximo treino é o seguinte ao último concluído, não importa o dia.
  final bool rotation;

  /// Treinos da sequência, na ordem.
  final List<RoutineItem> sequence;

  /// Próximo treino da sequência (null fora do modo sequência).
  final int? nextWorkoutId;

  static const weekdays = Routine(rotation: false);

  /// Posição do treino na sequência (1, 2, 3...) ou null se ele não faz parte.
  int? orderOf(int workoutId) => sequence.where((i) => i.workoutId == workoutId).firstOrNull?.order;

  /// O treino que vem depois de [workoutId] na sequência (volta ao começo no fim).
  int? after(int workoutId) {
    final index = sequence.indexWhere((i) => i.workoutId == workoutId);
    if (index < 0 || sequence.isEmpty) return null;
    return sequence[(index + 1) % sequence.length].workoutId;
  }

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
        rotation: json['mode'] == 'ROTATION',
        sequence: [
          for (final item in (json['sequence'] as List<dynamic>? ?? const []))
            RoutineItem(
              workoutId: ((item as Map<String, dynamic>)['workoutId'] as num).toInt(),
              name: item['workoutName'] as String? ?? 'Treino',
              order: (item['order'] as num).toInt(),
            ),
        ],
        nextWorkoutId: (json['nextWorkoutId'] as num?)?.toInt(),
      );
}

class RoutineItem {
  const RoutineItem({required this.workoutId, required this.name, required this.order});

  final int workoutId;
  final String name;
  final int order;
}

/// "A → B → C" com os nomes dos treinos da sequência.
String describeSequence(Routine routine) => routine.sequence.map((i) => i.name).join(' → ');
