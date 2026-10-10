import 'completion.dart';
import 'evolution.dart';
import 'training_stats.dart';
import 'workout_session.dart';

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Volume (repetições x carga) das séries de uma sessão.
double sessionVolume(WorkoutSession session) => WorkoutCompletion.volumeOf(session.performances);

/// Sessões finalizadas, da mais recente para a mais antiga.
List<WorkoutSession> finishedSessions(List<WorkoutSession> sessions) =>
    [for (final s in sessions) if (!s.isOpen) s]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

/// Números do mês exibido no calendário do Histórico. Tudo vem das sessões finalizadas.
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.levels,
    required this.volumeKg,
    required this.sessionCount,
  });

  /// Primeiro dia do mês.
  final DateTime month;

  /// Intensidade (1 a 3) de cada dia com treino; dias sem treino não aparecem.
  final Map<int, int> levels;
  final double volumeKg;
  final int sessionCount;

  int get daysInMonth => DateTime(month.year, month.month + 1, 0).day;

  /// Quantas células vazias antes do dia 1 (a semana começa na segunda).
  int get leadingBlanks => month.weekday - DateTime.monday;

  factory MonthSummary.of(List<WorkoutSession> sessions, DateTime month) {
    final first = DateTime(month.year, month.month);
    final inMonth = [
      for (final s in finishedSessions(sessions))
        if (s.startedAt.toLocal().year == first.year && s.startedAt.toLocal().month == first.month) s,
    ];
    final volumeByDay = <int, double>{};
    for (final s in inMonth) {
      final day = s.startedAt.toLocal().day;
      volumeByDay[day] = (volumeByDay[day] ?? 0) + sessionVolume(s);
    }
    final peak = volumeByDay.values.fold(0.0, (a, b) => a > b ? a : b);
    int levelOf(double volume) {
      if (peak <= 0 || volume <= 0) return 1;
      final ratio = volume / peak;
      return ratio <= 1 / 3 ? 1 : (ratio <= 2 / 3 ? 2 : 3);
    }

    return MonthSummary(
      month: first,
      levels: {for (final e in volumeByDay.entries) e.key: levelOf(e.value)},
      volumeKg: volumeByDay.values.fold(0.0, (a, b) => a + b),
      sessionCount: inMonth.length,
    );
  }
}

/// Valor de uma semana (identificada pela segunda-feira).
class WeekPoint {
  const WeekPoint(this.weekStart, this.value);

  final DateTime weekStart;
  final double value;
}

/// Maior carga do exercício em cada semana com treino (as últimas [maxWeeks] semanas).
List<WeekPoint> weeklyMaxLoad(ExerciseProgress progress, {int maxWeeks = 8}) {
  final byWeek = <DateTime, double>{};
  for (final point in progress.points) {
    final load = point.maxLoadKg;
    if (load == null) continue;
    final week = mondayOf(point.date);
    final current = byWeek[week];
    if (current == null || load > current) byWeek[week] = load;
  }
  final weeks = byWeek.keys.toList()..sort();
  final recent = weeks.length > maxWeeks ? weeks.sublist(weeks.length - maxWeeks) : weeks;
  return [for (final week in recent) WeekPoint(week, byWeek[week]!)];
}

/// Volume total de cada uma das últimas [weeks] semanas (inclui semanas sem treino, com 0),
/// da mais antiga para a semana atual.
List<WeekPoint> weeklyVolume(List<WorkoutSession> sessions, DateTime now, {int weeks = 8}) {
  final monday = mondayOf(now);
  final volumeByWeek = <DateTime, double>{};
  for (final s in finishedSessions(sessions)) {
    final week = mondayOf(s.startedAt);
    volumeByWeek[week] = (volumeByWeek[week] ?? 0) + sessionVolume(s);
  }
  return [
    for (var i = weeks - 1; i >= 0; i--)
      () {
        final week = DateTime(monday.year, monday.month, monday.day - 7 * i);
        return WeekPoint(week, volumeByWeek[week] ?? 0);
      }(),
  ];
}

/// Ganho percentual entre a primeira e a última semana da série (null se não der para comparar).
int? gainPercent(List<WeekPoint> series) {
  if (series.length < 2 || series.first.value <= 0) return null;
  return ((series.last.value / series.first.value - 1) * 100).round();
}

/// Quantas semanas separam a primeira e a última marca da série.
int weeksSpan(List<WeekPoint> series) =>
    series.length < 2 ? 0 : series.last.weekStart.difference(series.first.weekStart).inDays ~/ 7;

/// Maior carga da série (null se vazia).
double? bestOf(List<WeekPoint> series) =>
    series.isEmpty ? null : series.map((p) => p.value).reduce((a, b) => a > b ? a : b);

/// Treinos finalizados no mês de [now].
int sessionsInMonth(List<WorkoutSession> sessions, DateTime now) =>
    MonthSummary.of(sessions, now).sessionCount;

/// Minutos de duração ("<1 min" para sessões muito curtas).
String durationLabel(WorkoutSession session) {
  final end = session.finishedAt;
  if (end == null) return 'Em andamento';
  final minutes = end.difference(session.startedAt).inMinutes;
  return minutes < 1 ? '<1 min' : '$minutes min';
}

/// Mesmo dia civil (ignora horário).
bool isSameDay(DateTime a, DateTime b) => _dateOnly(a) == _dateOnly(b);

/// Quantas vezes o aluno bateu o próprio recorde de carga: sessões em que a carga máxima de um
/// exercício superou todas as anteriores (a primeira marca de cada exercício não conta).
int recordCount(List<ExerciseProgress> progress) {
  var records = 0;
  for (final exercise in progress) {
    double? best;
    for (final point in exercise.points) {
      final load = point.maxLoadKg;
      if (load == null) continue;
      if (best != null && load > best) records++;
      if (best == null || load > best) best = load;
    }
  }
  return records;
}
