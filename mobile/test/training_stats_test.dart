import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/features/sessions/domain/training_stats.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';
import 'package:gymmanager_mobile/features/workouts/domain/plan_stats.dart';
import 'package:gymmanager_mobile/features/workouts/domain/workout.dart';
import 'package:gymmanager_mobile/features/workouts/domain/workout_name.dart';

// Quinta, 8 de outubro de 2026 (a semana começa na segunda, 5/out).
final _now = DateTime(2026, 10, 8, 18);

WorkoutSession _s(int id, DateTime start, {bool finished = true, int workoutId = 10}) => WorkoutSession(
      id: id,
      workoutId: workoutId,
      startedAt: start,
      finishedAt: finished ? start.add(const Duration(minutes: 40)) : null,
    );

PlanRow _row(int sets, int reps, String? group, {int? rest}) => PlanRow(
      item: PlanItem(id: 1, exerciseId: 1, sets: sets, reps: reps, restSeconds: rest),
      exerciseName: 'Ex',
      muscleGroup: group,
    );

void main() {
  group('TrainingStats', () {
    test('sem sessões: dia atual é "hoje", passados são descanso e futuros ficam vazios', () {
      final stats = TrainingStats.from(const [], now: _now);

      expect(stats.weekDays.map((d) => d.state), [
        DayState.rest, DayState.rest, DayState.rest, DayState.today, DayState.future, DayState.future, DayState.future,
      ]);
      expect(stats.streakWeeks, 0);
      expect(stats.sessionsThisWeek, 0);
      expect(stats.trainedToday, isFalse);
    });

    test('treino finalizado marca o dia, conta na semana e vira "treinou hoje"', () {
      final stats = TrainingStats.from([
        _s(1, DateTime(2026, 10, 6, 9)),
        _s(2, DateTime(2026, 10, 8, 7)),
      ], now: _now);

      expect(stats.weekDays[1].state, DayState.done);
      expect(stats.weekDays[3].state, DayState.done);
      expect(stats.sessionsThisWeek, 2);
      expect(stats.trainedToday, isTrue);
      expect(stats.todaySession?.id, 2);
    });

    test('sessão em andamento hoje some com o lembrete, mas não conta como treino feito', () {
      final stats = TrainingStats.from([_s(1, DateTime(2026, 10, 8, 17), finished: false)], now: _now);

      expect(stats.trainedToday, isTrue);
      expect(stats.todaySession, isNull);
      expect(stats.sessionsThisWeek, 0);
      expect(stats.weekDays[3].state, DayState.today);
    });

    test('sequência conta semanas seguidas, mesmo se a semana atual ainda não tem treino', () {
      final stats = TrainingStats.from([
        _s(1, DateTime(2026, 9, 29, 9)), // semana de 28/set
        _s(2, DateTime(2026, 10, 1, 9)),
        _s(3, DateTime(2026, 9, 22, 9)), // semana de 21/set
      ], now: _now);

      expect(stats.streakWeeks, 2);
    });

    test('semana inteira sem treino quebra a sequência', () {
      final stats = TrainingStats.from([_s(1, DateTime(2026, 9, 14, 9))], now: _now);
      expect(stats.streakWeeks, 0);
    });

    test('semana atual com treino entra na sequência', () {
      final stats = TrainingStats.from([
        _s(1, DateTime(2026, 10, 5, 9)),
        _s(2, DateTime(2026, 9, 30, 9)),
      ], now: _now);
      expect(stats.streakWeeks, 2);
    });
  });

  group('suggestedWorkoutId', () {
    test('treino nunca feito vem primeiro', () {
      final id = suggestedWorkoutId([10, 11], [_s(1, DateTime(2026, 10, 1), workoutId: 10)]);
      expect(id, 11);
    });

    test('entre todos já feitos, o mais antigo', () {
      final id = suggestedWorkoutId([10, 11], [
        _s(1, DateTime(2026, 10, 5), workoutId: 10),
        _s(2, DateTime(2026, 10, 1), workoutId: 11),
      ]);
      expect(id, 11);
    });

    test('lista vazia não sugere nada; sem histórico fica o primeiro', () {
      expect(suggestedWorkoutId(const [], const []), isNull);
      expect(suggestedWorkoutId([10, 11], const []), 10);
    });
  });

  group('PlanStats', () {
    test('soma séries, estima duração e distribui o foco somando 100%', () {
      final stats = PlanStats.from([
        _row(3, 10, 'Peito', rest: 60),
        _row(3, 10, 'Pernas', rest: 60),
        _row(3, 10, 'Costas', rest: 60),
      ]);

      expect(stats.exercises, 3);
      expect(stats.sets, 9);
      // 9 séries x (30 s + 60 s) + 3 x 60 s = 990 s -> 17 min
      expect(stats.estimatedMinutes, 17);
      expect(stats.focus.fold<int>(0, (a, f) => a + f.percent), 100);
      expect(stats.focus.map((f) => f.percent).toSet(), {33, 34});
    });

    test('grupo vazio vira "Outros" e plano vazio não quebra', () {
      expect(PlanStats.from([_row(2, 8, null)]).focus.single.group, 'Outros');
      final empty = PlanStats.from(const []);
      expect(empty.sets, 0);
      expect(empty.focus, isEmpty);
    });
  });

  group('splitWorkoutName', () {
    test('separa etiqueta e título', () {
      expect(splitWorkoutName('Treino A - Full body'), (tag: 'Treino A', title: 'Full body'));
      expect(splitWorkoutName('Treino B · Superior'), (tag: 'Treino B', title: 'Superior'));
    });

    test('sem separador, o nome inteiro é o título; hífen colado não separa', () {
      expect(splitWorkoutName('Peito e tríceps'), (tag: null, title: 'Peito e tríceps'));
      expect(splitWorkoutName('Full-body'), (tag: null, title: 'Full-body'));
    });
  });
}
