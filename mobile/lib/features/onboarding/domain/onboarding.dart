/// Objetivo principal do aluno.
enum TrainingGoal {
  hypertrophy('HYPERTROPHY', 'Ganhar massa muscular', 'Músculos maiores e mais definidos'),
  weightLoss('WEIGHT_LOSS', 'Emagrecer', 'Perder gordura mantendo os músculos'),
  strength('STRENGTH', 'Ficar mais forte', 'Levantar mais carga'),
  conditioning('CONDITIONING', 'Condicionamento', 'Mais fôlego e disposição'),
  health('HEALTH', 'Saúde e bem-estar', 'Mexer o corpo com regularidade');

  const TrainingGoal(this.api, this.label, this.description);

  final String api;
  final String label;
  final String description;
}

enum TrainingLevel {
  beginner('BEGINNER', 'Iniciante', 'Treino há menos de 6 meses (ou nunca treinei)'),
  intermediate('INTERMEDIATE', 'Intermediário', 'Treino com frequência há mais de 6 meses'),
  advanced('ADVANCED', 'Avançado', 'Treino há anos, conheço bem os exercícios');

  const TrainingLevel(this.api, this.label, this.description);

  final String api;
  final String label;
  final String description;
}

enum TrainingLocation {
  gym('GYM', 'Academia', 'Com aparelhos, barras e halteres'),
  home('HOME', 'Em casa, com equipamento', 'Halteres, elásticos, barra...'),
  bodyweight('BODYWEIGHT', 'Só com o peso do corpo', 'Sem nenhum equipamento');

  const TrainingLocation(this.api, this.label, this.description);

  final String api;
  final String label;
  final String description;
}

enum Equipment {
  dumbbells('DUMBBELLS', 'Halteres'),
  barbell('BARBELL', 'Barra e anilhas'),
  bench('BENCH', 'Banco'),
  kettlebell('KETTLEBELL', 'Kettlebell'),
  bands('BANDS', 'Elásticos'),
  pullUpBar('PULL_UP_BAR', 'Barra fixa'),
  machines('MACHINES', 'Algum aparelho');

  const Equipment(this.api, this.label);

  final String api;
  final String label;
}

T? _byApi<T extends Enum>(List<T> values, String? api, String Function(T) apiOf) {
  for (final v in values) {
    if (apiOf(v) == api) return v;
  }
  return null;
}

/// Preferências de treino do aluno.
class TrainingProfile {
  const TrainingProfile({
    required this.goal,
    required this.level,
    required this.daysPerWeek,
    required this.minutesPerSession,
    required this.location,
    this.equipment = const {},
    this.height,
    this.weight,
  });

  final TrainingGoal goal;
  final TrainingLevel level;
  final int daysPerWeek;
  final int minutesPerSession;
  final TrainingLocation location;
  final Set<Equipment> equipment;
  final double? height;
  final double? weight;

  static TrainingProfile? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final goal = _byApi(TrainingGoal.values, json['goal'] as String?, (g) => g.api);
    final level = _byApi(TrainingLevel.values, json['level'] as String?, (l) => l.api);
    final location = _byApi(TrainingLocation.values, json['location'] as String?, (l) => l.api);
    if (goal == null || level == null || location == null) return null;
    return TrainingProfile(
      goal: goal,
      level: level,
      daysPerWeek: (json['daysPerWeek'] as num).toInt(),
      minutesPerSession: (json['minutesPerSession'] as num).toInt(),
      location: location,
      equipment: {
        for (final e in (json['equipment'] as List<dynamic>? ?? const []))
          if (_byApi(Equipment.values, e as String, (x) => x.api) case final Equipment eq) eq,
      },
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'goal': goal.api,
        'level': level.api,
        'daysPerWeek': daysPerWeek,
        'minutesPerSession': minutesPerSession,
        'location': location.api,
        'equipment': location == TrainingLocation.home ? [for (final e in equipment) e.api] : <String>[],
        'height': height,
        'weight': weight,
      };
}

/// Situação do onboarding do aluno.
class OnboardingStatus {
  const OnboardingStatus({
    this.trainingProfile,
    this.screeningRisk,
    this.screeningAnsweredAt,
    required this.completed,
    required this.aiWorkoutsAllowed,
  });

  final TrainingProfile? trainingProfile;

  /// null = triagem ainda não respondida.
  final bool? screeningRisk;
  final DateTime? screeningAnsweredAt;
  final bool completed;
  final bool aiWorkoutsAllowed;

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    final screening = json['healthScreening'] as Map<String, dynamic>?;
    return OnboardingStatus(
      trainingProfile: TrainingProfile.fromJson(json['trainingProfile'] as Map<String, dynamic>?),
      screeningRisk: screening?['risk'] as bool?,
      screeningAnsweredAt: screening?['answeredAt'] == null ? null : DateTime.parse(screening!['answeredAt'] as String),
      completed: json['completed'] as bool? ?? false,
      aiWorkoutsAllowed: json['aiWorkoutsAllowed'] as bool? ?? false,
    );
  }
}

/// Perguntas da triagem de saúde, na ordem que o servidor espera (versão "triagem-2026-10").
/// Texto próprio, inspirado em questionários de prontidão para atividade física (como o PAR-Q+).
const screeningQuestions = [
  'Algum médico já disse que você tem problema no coração ou pressão alta?',
  'Você sente dor no peito em repouso, nas atividades do dia a dia ou quando faz exercício?',
  'Nos últimos 12 meses, você perdeu o equilíbrio por tontura ou desmaiou?',
  'Você tem alguma outra doença crônica diagnosticada (como diabetes, asma, doença nos rins ou no fígado)?',
  'Você toma remédio receitado para alguma doença crônica?',
  'Você tem problema nos ossos, articulações ou músculos (inclusive lesão ou cirurgia recente) que pode piorar com exercício?',
  'Você está grávida, ou algum médico já disse que você só deve fazer atividade física com acompanhamento médico?',
];
