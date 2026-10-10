import 'workout_session.dart';

enum DayState { done, today, rest, future }

class WeekDay {
  const WeekDay(this.label, this.state);

  /// Inicial do dia (S T Q Q S S D, começando na segunda).
  final String label;
  final DayState state;
}

const _dayLabels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Segunda-feira da semana de [date] (semanas começam na segunda).
DateTime mondayOf(DateTime date) {
  final day = _dateOnly(date);
  return DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));
}

/// Números da home calculados do histórico de sessões (nada é gravado no banco:
/// se uma série for editada ou apagada, o número acompanha).
class TrainingStats {
  const TrainingStats({
    required this.weekDays,
    required this.sessionsThisWeek,
    required this.streakWeeks,
    required this.trainedToday,
    this.todaySession,
  });

  final List<WeekDay> weekDays;

  /// Treinos finalizados na semana atual.
  final int sessionsThisWeek;

  /// Semanas seguidas com ao menos um treino finalizado.
  final int streakWeeks;

  /// Há sessão iniciada hoje (finalizada ou em andamento): some o lembrete.
  final bool trainedToday;

  /// Última sessão finalizada hoje, se houver.
  final WorkoutSession? todaySession;

  factory TrainingStats.from(List<WorkoutSession> sessions, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final monday = mondayOf(today);
    final finished = [for (final s in sessions) if (!s.isOpen) s];

    final finishedDays = {for (final s in finished) _dateOnly(s.startedAt)};
    final trainedToday = sessions.any((s) => _dateOnly(s.startedAt) == today);

    final weekDays = <WeekDay>[
      for (var i = 0; i < 7; i++)
        () {
          final day = DateTime(monday.year, monday.month, monday.day + i);
          final label = _dayLabels[i];
          if (finishedDays.contains(day)) return WeekDay(label, DayState.done);
          if (day == today) return WeekDay(label, DayState.today);
          return WeekDay(label, day.isBefore(today) ? DayState.rest : DayState.future);
        }(),
    ];

    final weeksWithTraining = {for (final s in finished) mondayOf(s.startedAt)};
    // Semana atual sem treino ainda não quebra a sequência (a semana não acabou):
    // a contagem parte da semana anterior.
    var cursor = weeksWithTraining.contains(monday) ? monday : DateTime(monday.year, monday.month, monday.day - 7);
    var streak = 0;
    while (weeksWithTraining.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 7);
    }

    final todays = [for (final s in finished) if (_dateOnly(s.startedAt) == today) s]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return TrainingStats(
      weekDays: weekDays,
      sessionsThisWeek: finished.where((s) => !_dateOnly(s.startedAt).isBefore(monday)).length,
      streakWeeks: streak,
      trainedToday: trainedToday,
      todaySession: todays.isEmpty ? null : todays.first,
    );
  }
}

/// Treino sugerido para hoje: o que está há mais tempo sem ser feito (nunca feito vem
/// primeiro; empate mantém a ordem da lista). Não há agenda por dia da semana no backend.
int? suggestedWorkoutId(List<int> workoutIds, List<WorkoutSession> sessions) {
  if (workoutIds.isEmpty) return null;
  final lastDone = <int, DateTime>{};
  for (final s in sessions) {
    final current = lastDone[s.workoutId];
    if (current == null || s.startedAt.isAfter(current)) lastDone[s.workoutId] = s.startedAt;
  }
  int? best;
  DateTime? bestDate;
  var bestNever = false;
  for (final id in workoutIds) {
    final date = lastDone[id];
    if (date == null) {
      if (!bestNever) {
        best = id;
        bestNever = true;
      }
      continue;
    }
    if (bestNever) continue;
    if (bestDate == null || date.isBefore(bestDate)) {
      best = id;
      bestDate = date;
    }
  }
  return best;
}
