import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/auth/domain/student_profile.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';
import 'package:gymmanager_mobile/features/workouts/domain/routine.dart';
import 'package:gymmanager_mobile/features/workouts/domain/workout.dart';
import 'package:gymmanager_mobile/features/workouts/presentation/my_workouts_page.dart';

import 'support/fake_repositories.dart';
import 'support/fakes.dart';

List<Override> _overrides(List<WorkoutSession> sessions, {int? weeklyGoal}) => [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage(StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)))),
      ),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(
        profile: StudentProfile(id: 2, email: 'a@a.com', name: 'Maria Aluna', weeklyGoal: weeklyGoal),
      )),
      sessionRepositoryProvider.overrideWithValue(FakeSessionRepository(initial: sessions)),
      workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
    ];

Widget _app(List<WorkoutSession> sessions, {int? weeklyGoal}) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: _overrides(sessions, weeklyGoal: weeklyGoal),
      child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: MyWorkoutsPage())),
    );

/// Treino A nas segundas e quartas, treino B nas terças e sextas.
class _WeekRepository extends FakeWorkoutRepository {
  final saved = <Map<int, Set<int>>>[];

  @override
  Future<List<Workout>> myWorkouts(int studentId) async => const [
        Workout(id: 10, name: 'Treino A', weekdays: [1, 3]),
        Workout(id: 11, name: 'Treino B', weekdays: [2, 5]),
      ];

  @override
  Future<List<Workout>> setSchedule(int studentId, Map<int, Set<int>> days) async {
    saved.add(days);
    return myWorkouts(studentId);
  }

  /// Esquema devolvido pelo servidor (dias da semana até alguém montar uma sequência).
  Routine current = Routine.weekdays;
  final routineCalls = <String>[];

  @override
  Future<Routine> routine(int studentId) async => current;

  @override
  Future<Routine> setRoutine(int studentId, List<int> workoutIds) async {
    routineCalls.add('set:${workoutIds.join(',')}');
    return current;
  }

  @override
  Future<Routine> skipTo(int studentId, int workoutId) async {
    routineCalls.add('skip:$workoutId');
    return current;
  }
}

const _sequenceBA = Routine(
  rotation: true,
  sequence: [RoutineItem(workoutId: 11, name: 'Treino B', order: 1), RoutineItem(workoutId: 10, name: 'Treino A', order: 2)],
  nextWorkoutId: 11,
);

Widget _weekApp(DateTime now, _WeekRepository repo, {bool hasTrainer = true}) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage(StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)))),
        ),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(
          profile: StudentProfile(id: 2, email: 'a@a.com', name: 'Maria Aluna', hasTrainer: hasTrainer),
        )),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        workoutRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: MyWorkoutsPage())),
    );

void main() {
  group('semana de treinos', () {
    testWidgets('no dia marcado, o cartão é o treino do dia; os outros mostram os dias', (tester) async {
      await tester.pumpWidget(_weekApp(DateTime(2026, 10, 21, 9), _WeekRepository())); // quarta
      await tester.pumpAndSettle();

      expect(find.text('TREINO DE HOJE'), findsOneWidget);
      expect(find.text('TREINO A'), findsOneWidget);
      expect(find.byKey(const Key('today-reminder')), findsOneWidget);
      expect(find.text('Ter · Sex'), findsOneWidget);
    });

    testWidgets('dia sem treino é descanso e o cartão mostra o próximo', (tester) async {
      await tester.pumpWidget(_weekApp(DateTime(2026, 10, 22, 9), _WeekRepository())); // quinta
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('today-rest')), findsOneWidget);
      expect(find.text('PRÓXIMO · SEXTA'), findsOneWidget);
      expect(find.text('TREINO B'), findsOneWidget);
      expect(find.byKey(const Key('workout-10')), findsOneWidget);
    });

    testWidgets('na sequência, o cartão é o próximo dela (os dias não valem) e dá para pular', (tester) async {
      final repo = _WeekRepository()..current = _sequenceBA;
      // quinta: pelos dias seria descanso, mas na sequência o próximo é o B
      await tester.pumpWidget(_weekApp(DateTime(2026, 10, 22, 9), repo));
      await tester.pumpAndSettle();

      expect(find.text('PRÓXIMO DA SEQUÊNCIA'), findsOneWidget);
      expect(find.text('TREINO B'), findsOneWidget);
      expect(find.byKey(const Key('today-rest')), findsNothing);
      expect(find.text('2º da sequência'), findsOneWidget);

      await tester.tap(find.byKey(const Key('skip-sequence')));
      await tester.pumpAndSettle();
      expect(repo.routineCalls, ['skip:10']);
    });

    testWidgets('aluno sem personal monta a própria sequência', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _WeekRepository();
      await tester.pumpWidget(_weekApp(DateTime(2026, 10, 21, 9), repo, hasTrainer: false));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('own-sequence')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sequence-sheet')), findsOneWidget);
      // sem sequência ainda: todos marcados, na ordem da lista
      await tester.tap(find.byKey(const Key('seq-check-11')));
      await tester.pump();
      expect(find.text('MARQUE 2 OU MAIS TREINOS'), findsOneWidget);
      await tester.tap(find.byKey(const Key('seq-check-11')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-sequence')));
      await tester.pumpAndSettle();

      expect(repo.routineCalls, ['set:10,11']);
    });

    testWidgets('aluno sem personal organiza a própria semana', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _WeekRepository();
      await tester.pumpWidget(_weekApp(DateTime(2026, 10, 21, 9), repo, hasTrainer: false));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('own-week')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('week-schedule')), findsOneWidget);
      await tester.tap(find.byKey(const Key('day-1-workout-11'))); // B também na segunda
      await tester.pump();
      await tester.tap(find.byKey(const Key('day-3-workout-10'))); // A sai da quarta
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-week')));
      await tester.pumpAndSettle();

      expect(repo.saved.single, {10: {1}, 11: {1, 2, 5}});
    });
  });

  testWidgets('mostra saudação, semana, treino sugerido e os próximos treinos', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();

    expect(find.text('BORA, MARIA'), findsOneWidget);
    expect(find.byKey(const Key('streak-text')), findsOneWidget);
    expect(find.byKey(const Key('workout-hero')), findsOneWidget);
    // FakeWorkoutRepository tem "Treino A" e "Treino B": o primeiro nunca feito vira o hero
    expect(find.text('TREINO A'), findsOneWidget);
    expect(find.byKey(const Key('workout-11')), findsOneWidget);
    expect(find.byKey(const Key('workout-10')), findsNothing);
    expect(find.byKey(const Key('today-reminder')), findsOneWidget);
  });

  testWidgets('sem meta definida pelo personal, o card não mostra meta', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weekly-goal')), findsNothing);
  });

  testWidgets('com meta definida, mostra "N de M treinos"', (tester) async {
    await tester.pumpWidget(_app(const [], weeklyGoal: 4));
    await tester.pumpAndSettle();
    expect(find.text('Meta · 0 de 4 treinos'), findsOneWidget);
  });

  testWidgets('depois de treinar hoje, o hero vira o resumo e o alerta fica verde', (tester) async {
    final start = DateTime.now(); // exatamente agora: evita virar "ontem" se o teste rodar à meia-noite
    await tester.pumpWidget(_app([
      WorkoutSession(
        id: 1,
        workoutId: 10,
        startedAt: start,
        finishedAt: start.add(const Duration(minutes: 45)),
        performances: const [Performance(id: 1, workoutExerciseId: 100, setNumber: 1, reps: 10, loadKg: 20)],
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workout-hero')), findsNothing);
    expect(find.byKey(const Key('today-done-card')), findsOneWidget);
    expect(find.byKey(const Key('today-done')), findsOneWidget);
    expect(find.text('45:00'), findsOneWidget);
    expect(find.text('200 kg'), findsOneWidget);
    // o treino feito hoje não repete na lista; o outro continua em "Próximos treinos"
    expect(find.byKey(const Key('workout-10')), findsNothing);
    expect(find.byKey(const Key('workout-11')), findsOneWidget);
  });
}
