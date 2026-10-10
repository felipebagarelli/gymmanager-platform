import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/features/sessions/domain/evolution.dart';
import 'package:gymmanager_mobile/features/sessions/domain/history_stats.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';

WorkoutSession _session(int id, DateTime start, List<Performance> sets, {bool open = false}) => WorkoutSession(
      id: id,
      workoutId: 10,
      startedAt: start,
      finishedAt: open ? null : start.add(const Duration(minutes: 45)),
      performances: sets,
    );

Performance _set(int id, int reps, double? load) =>
    Performance(id: id, workoutExerciseId: 100, setNumber: id, reps: reps, loadKg: load);

void main() {
  group('MonthSummary', () {
    test('outubro de 2026 começa numa quinta (3 células vazias) e tem 31 dias', () {
      final summary = MonthSummary.of(const [], DateTime(2026, 10, 15));
      expect(summary.month, DateTime(2026, 10));
      expect(summary.leadingBlanks, 3);
      expect(summary.daysInMonth, 31);
      expect(summary.levels, isEmpty);
      expect(summary.sessionCount, 0);
    });

    test('nível pela proporção do volume do dia em relação ao maior do mês', () {
      final summary = MonthSummary.of([
        _session(1, DateTime(2026, 10, 2, 9), [_set(1, 10, 10)]), // 100
        _session(2, DateTime(2026, 10, 5, 9), [_set(2, 10, 50)]), // 500 (50%)
        _session(3, DateTime(2026, 10, 8, 9), [_set(3, 10, 100)]), // 1000 (maior)
      ], DateTime(2026, 10));

      expect(summary.levels, {2: 1, 5: 2, 8: 3});
      expect(summary.volumeKg, 1600);
      expect(summary.sessionCount, 3);
    });

    test('dois treinos no mesmo dia somam; sessão em andamento e outros meses ficam de fora', () {
      final summary = MonthSummary.of([
        _session(1, DateTime(2026, 10, 2, 8), [_set(1, 10, 10)]),
        _session(2, DateTime(2026, 10, 2, 18), [_set(2, 10, 10)]),
        _session(3, DateTime(2026, 10, 3, 9), [_set(3, 10, 99)], open: true),
        _session(4, DateTime(2026, 9, 30, 9), [_set(4, 10, 99)]),
      ], DateTime(2026, 10));

      expect(summary.levels.keys, [2]);
      expect(summary.volumeKg, 200);
      expect(summary.sessionCount, 2);
    });

    test('dia só com peso do corpo (volume 0) ainda aparece, no nível mínimo', () {
      final summary = MonthSummary.of([_session(1, DateTime(2026, 10, 2), [_set(1, 15, null)])], DateTime(2026, 10));
      expect(summary.levels, {2: 1});
      expect(summary.volumeKg, 0);
    });
  });

  group('séries semanais', () {
    ExerciseProgress progress(List<(DateTime, double?)> data) => ExerciseProgress(
          exerciseName: 'Supino',
          points: [for (final d in data) ProgressPoint(date: d.$1, maxLoadKg: d.$2, totalReps: 10)],
        );

    test('carga máxima por semana: pega a maior da semana e ignora pontos sem carga', () {
      final series = weeklyMaxLoad(progress([
        (DateTime(2026, 9, 21), 40), // segunda
        (DateTime(2026, 9, 24), 45), // mesma semana
        (DateTime(2026, 9, 25), null),
        (DateTime(2026, 10, 5), 50),
      ]));

      expect(series.map((p) => p.value), [45, 50]);
      expect(series.map((p) => p.weekStart), [DateTime(2026, 9, 21), DateTime(2026, 10, 5)]);
    });

    test('mantém só as últimas semanas pedidas', () {
      final series = weeklyMaxLoad(
        progress([for (var i = 0; i < 10; i++) (DateTime(2026, 8, 3 + 7 * i), 20.0 + i)]),
        maxWeeks: 8,
      );
      expect(series, hasLength(8));
      expect(series.last.value, 29);
      expect(series.first.value, 22);
    });

    test('volume semanal: 8 semanas até a atual, com 0 nas sem treino', () {
      final weeks = weeklyVolume([
        _session(1, DateTime(2026, 10, 6), [_set(1, 10, 40)]),
        _session(2, DateTime(2026, 10, 8), [_set(2, 10, 60)]),
        _session(3, DateTime(2026, 9, 21), [_set(3, 10, 30)]),
        _session(4, DateTime(2026, 10, 9), [_set(4, 10, 999)], open: true),
      ], DateTime(2026, 10, 10));

      expect(weeks, hasLength(8));
      expect(weeks.last.weekStart, DateTime(2026, 10, 5));
      expect(weeks.last.value, 1000);
      expect(weeks.first.weekStart, DateTime(2026, 8, 17));
      expect(weeks[5].value, 300); // semana de 21/9
      expect(weeks[6].value, 0);
    });

    test('ganho percentual e intervalo em semanas', () {
      final series = [
        WeekPoint(DateTime(2026, 9, 7), 40),
        WeekPoint(DateTime(2026, 9, 21), 42),
        WeekPoint(DateTime(2026, 10, 5), 50),
      ];
      expect(gainPercent(series), 25);
      expect(weeksSpan(series), 4);
      expect(bestOf(series), 50);
    });

    test('ganho não existe com 1 ponto ou base zero', () {
      expect(gainPercent([WeekPoint(DateTime(2026, 9, 7), 40)]), isNull);
      expect(gainPercent([WeekPoint(DateTime(2026, 9, 7), 0), WeekPoint(DateTime(2026, 9, 14), 5)]), isNull);
      expect(bestOf(const []), isNull);
    });
  });

  test('duração em minutos, com "<1 min" e "Em andamento"', () {
    final start = DateTime(2026, 10, 2, 9);
    expect(durationLabel(_session(1, start, const [])), '45 min');
    expect(
      durationLabel(WorkoutSession(id: 1, workoutId: 10, startedAt: start, finishedAt: start.add(const Duration(seconds: 30)))),
      '<1 min',
    );
    expect(durationLabel(_session(1, start, const [], open: true)), 'Em andamento');
  });
}
