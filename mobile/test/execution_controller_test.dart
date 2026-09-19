import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';

import 'support/fake_repositories.dart';
import 'support/fakes.dart';

Future<ProviderContainer> makeContainer(FakeSessionRepository sessions) async {
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      sessionRepositoryProvider.overrideWithValue(sessions),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authControllerProvider.notifier).login('aluno@example.com', 'senha');
  return container;
}

void main() {
  const workoutId = 10;

  test('sem sessao aberta para o treino, o estado e null', () async {
    final container = await makeContainer(FakeSessionRepository());

    expect(await container.read(executionProvider(workoutId).future), isNull);
  });

  test('retoma a sessao em andamento do mesmo treino, ignorando outros treinos e finalizadas', () async {
    final open = WorkoutSession(id: 1, workoutId: workoutId, startedAt: DateTime.now());
    final otherWorkout = WorkoutSession(id: 2, workoutId: 99, startedAt: DateTime.now());
    final finished = WorkoutSession(
      id: 3,
      workoutId: workoutId,
      startedAt: DateTime.now(),
      finishedAt: DateTime.now(),
    );
    final container = await makeContainer(FakeSessionRepository(initial: [finished, otherWorkout, open]));

    final session = await container.read(executionProvider(workoutId).future);

    expect(session?.id, 1);
  });

  test('start cria a sessao e passa a expo-la', () async {
    final container = await makeContainer(FakeSessionRepository());
    await container.read(executionProvider(workoutId).future);

    await container.read(executionProvider(workoutId).notifier).start();

    final session = container.read(executionProvider(workoutId)).value;
    expect(session, isNotNull);
    expect(session!.isOpen, isTrue);
    expect(session.workoutId, workoutId);
  });

  test('addSet numera as series por exercicio (1, 2 no mesmo; 1 no outro)', () async {
    final repository = FakeSessionRepository();
    final container = await makeContainer(repository);
    await container.read(executionProvider(workoutId).future);
    final controller = container.read(executionProvider(workoutId).notifier);
    await controller.start();

    await controller.addSet(100, reps: 12, loadKg: 20);
    await controller.addSet(100, reps: 10, loadKg: 22.5);
    await controller.addSet(101, reps: 8);

    final session = container.read(executionProvider(workoutId)).value!;
    expect(session.setsOf(100).map((p) => p.setNumber), [1, 2]);
    expect(session.setsOf(100).map((p) => p.loadKg), [20, 22.5]);
    expect(session.setsOf(101).map((p) => p.setNumber), [1]);
    expect(session.setsOf(101).single.loadKg, isNull);
  });

  test('editSet preserva o numero da serie e removeSet apaga so aquela', () async {
    final container = await makeContainer(FakeSessionRepository());
    await container.read(executionProvider(workoutId).future);
    final controller = container.read(executionProvider(workoutId).notifier);
    await controller.start();
    await controller.addSet(100, reps: 12, loadKg: 20);
    await controller.addSet(100, reps: 10, loadKg: 20);

    final second = container.read(executionProvider(workoutId)).value!.setsOf(100)[1];
    await controller.editSet(second, reps: 9, loadKg: 25);
    var sets = container.read(executionProvider(workoutId)).value!.setsOf(100);
    expect(sets[1].setNumber, 2);
    expect(sets[1].reps, 9);
    expect(sets[1].loadKg, 25);

    await controller.removeSet(sets[0]);
    sets = container.read(executionProvider(workoutId)).value!.setsOf(100);
    expect(sets.map((p) => p.reps), [9]);
  });

  test('finish encerra a sessao, zera o estado e atualiza o historico', () async {
    final repository = FakeSessionRepository();
    final container = await makeContainer(repository);
    await container.read(executionProvider(workoutId).future);
    final controller = container.read(executionProvider(workoutId).notifier);
    await controller.start();
    await controller.addSet(100, reps: 12, loadKg: 20);

    await controller.finish();

    expect(container.read(executionProvider(workoutId)).value, isNull);
    final history = await container.read(historyProvider.future);
    expect(history.single.isOpen, isFalse);
    expect(history.single.performances, hasLength(1));
  });

  test('erro do servidor e propagado e a sessao anterior e mantida', () async {
    final repository = FakeSessionRepository();
    final container = await makeContainer(repository);
    await container.read(executionProvider(workoutId).future);
    final controller = container.read(executionProvider(workoutId).notifier);
    await controller.start();
    await controller.addSet(100, reps: 12, loadKg: 20);

    repository.failWith = AppException('Esta sessão já foi finalizada.', statusCode: 409);
    await expectLater(
      controller.addSet(100, reps: 10),
      throwsA(isA<AppException>().having((e) => e.statusCode, 'statusCode', 409)),
    );

    expect(container.read(executionProvider(workoutId)).value!.setsOf(100), hasLength(1));
  });

  test('depois de remover a serie 1, a proxima serie nao duplica o numero', () async {
    final container = await makeContainer(FakeSessionRepository());
    await container.read(executionProvider(workoutId).future);
    final controller = container.read(executionProvider(workoutId).notifier);
    await controller.start();
    await controller.addSet(100, reps: 12, loadKg: 20);
    await controller.addSet(100, reps: 10, loadKg: 20);

    final first = container.read(executionProvider(workoutId)).value!.setsOf(100).first;
    await controller.removeSet(first);
    await controller.addSet(100, reps: 8, loadKg: 20);

    final numbers = container.read(executionProvider(workoutId)).value!.setsOf(100).map((p) => p.setNumber);
    expect(numbers, [2, 3]);
  });
}
