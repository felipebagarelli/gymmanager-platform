import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/sessions/application/evolution_providers.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';
import 'package:gymmanager_mobile/features/sessions/presentation/evolution_page.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';

import 'support/fake_repositories.dart';
import 'support/fakes.dart';

WorkoutSession _finished(int id, {required int workoutId, required DateTime startedAt, List<Performance>? perf}) =>
    WorkoutSession(
      id: id,
      workoutId: workoutId,
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(minutes: 40)),
      performances: perf ?? const [],
    );

List<Override> _overrides({List<WorkoutSession>? sessions}) => [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage(StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)))),
      ),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      sessionRepositoryProvider.overrideWithValue(FakeSessionRepository(initial: sessions)),
      workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
    ];

Future<ProviderContainer> _container({List<WorkoutSession>? sessions}) async {
  final container = ProviderContainer(retry: (retryCount, error) => null, overrides: _overrides(sessions: sessions));
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);
  return container;
}

Widget _app({List<WorkoutSession>? sessions}) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: _overrides(sessions: sessions),
      child: const MaterialApp(home: Scaffold(body: EvolutionPage())),
    );

void main() {
  test('sem sessoes finalizadas, a evolucao fica vazia', () async {
    final container = await _container(sessions: []);
    expect(await container.read(evolutionProvider.future), isEmpty);
  });

  test('agrupa por exercicio, ordena por data e calcula melhor carga e a variacao', () async {
    // FakeWorkoutRepository: workoutExerciseId 100 = Supino, 101 = Agachamento
    final container = await _container(sessions: [
      _finished(1, workoutId: 10, startedAt: DateTime(2026, 9, 1), perf: const [
        Performance(id: 1, workoutExerciseId: 100, setNumber: 1, reps: 10, loadKg: 40),
        Performance(id: 2, workoutExerciseId: 100, setNumber: 2, reps: 10, loadKg: 42),
      ]),
      _finished(2, workoutId: 10, startedAt: DateTime(2026, 9, 8), perf: const [
        Performance(id: 3, workoutExerciseId: 100, setNumber: 1, reps: 10, loadKg: 45),
      ]),
    ]);

    final progress = await container.read(evolutionProvider.future);

    expect(progress, hasLength(1));
    expect(progress.single.exerciseName, 'Supino');
    expect(progress.single.points.map((p) => p.maxLoadKg), [42, 45]);
    expect(progress.single.bestLoadKg, 45);
    expect(progress.single.lastDeltaKg, 3);
  });

  test('sessao em andamento (sem finishedAt) e ignorada', () async {
    final container = await _container(sessions: [
      WorkoutSession(id: 1, workoutId: 10, startedAt: DateTime(2026, 9, 1), performances: const [
        Performance(id: 1, workoutExerciseId: 100, setNumber: 1, reps: 10, loadKg: 40),
      ]),
    ]);

    expect(await container.read(evolutionProvider.future), isEmpty);
  });

  test('serie sem carga informada ainda conta o volume (repeticoes)', () async {
    final container = await _container(sessions: [
      _finished(1, workoutId: 10, startedAt: DateTime(2026, 9, 1), perf: const [
        Performance(id: 1, workoutExerciseId: 101, setNumber: 1, reps: 12),
        Performance(id: 2, workoutExerciseId: 101, setNumber: 2, reps: 10),
      ]),
    ]);

    final progress = (await container.read(evolutionProvider.future)).single;
    expect(progress.exerciseName, 'Agachamento');
    expect(progress.hasLoadData, isFalse);
    expect(progress.points.single.totalReps, 22);
  });

  testWidgets('tela mostra os cards de progresso', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(sessions: [
      _finished(1, workoutId: 10, startedAt: DateTime(2026, 9, 1), perf: const [
        Performance(id: 1, workoutExerciseId: 100, setNumber: 1, reps: 10, loadKg: 40),
      ]),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('progress-Supino')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('record-value'))).data, '40 kg');
  });

  testWidgets('sem historico, mostra o estado vazio', (tester) async {
    await tester.pumpWidget(_app(sessions: []));
    await tester.pumpAndSettle();

    expect(find.textContaining('Finalize alguns treinos'), findsOneWidget);
  });
}
