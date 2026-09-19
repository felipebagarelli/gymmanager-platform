// Teste de contrato contra o backend REAL. Desligado por padrao.
//
// Uso (backend rodando em localhost:8080 com os dados de dev):
//   flutter test test/integration/api_contract_test.dart \
//     --dart-define=RUN_API_TESTS=true \
//     --dart-define=API_EMAIL=aluno@exemplo.com \
//     --dart-define=API_PASSWORD=... \
//     --dart-define=API_TRAINER_EMAIL=personal@exemplo.com
//
// ATENCAO: cria e finaliza uma sessao de treino real para esse aluno.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/network/api_client.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/auth/data/auth_repository.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/sessions/data/session_repository.dart';
import 'package:gymmanager_mobile/features/workouts/data/workout_repository.dart';

import '../support/fakes.dart';

const runApiTests = bool.fromEnvironment('RUN_API_TESTS');
const email = String.fromEnvironment('API_EMAIL');
const password = String.fromEnvironment('API_PASSWORD');
const trainerEmail = String.fromEnvironment('API_TRAINER_EMAIL');

void main() {
  final skip = runApiTests ? null : 'defina --dart-define=RUN_API_TESTS=true para rodar contra a API real';

  test('fluxo completo do aluno contra a API real', skip: skip, () async {
    final storage = InMemoryTokenStorage();
    var unauthorizedCalls = 0;
    final dio = buildDio(storage: storage, onUnauthorized: () => unauthorizedCalls++);
    final auth = AuthRepository(dio);

    // login + perfil
    final login = await auth.login(email, password);
    expect(login.role, 'STUDENT');
    expect(login.expiresInSeconds, greaterThan(0));
    await storage.save(
      StoredSessionFactory.valid(login.token),
    );
    final me = await auth.me();
    expect(me.id, greaterThan(0));
    expect(me.email, email);

    // treinos ativos e plano do primeiro treino que tenha exercicios
    final workouts = WorkoutRepository(dio);
    final exercises = {for (final e in await workouts.exercises()) e.id: e};
    final mine = await workouts.myWorkouts(me.id);
    expect(mine, isNotEmpty, reason: 'o aluno precisa ter um treino atribuido');

    var chosenWorkoutId = -1;
    for (final workout in mine) {
      final plan = await workouts.plan(workout.id);
      if (plan.isNotEmpty) {
        chosenWorkoutId = workout.id;
        break;
      }
    }
    expect(chosenWorkoutId, greaterThan(0), reason: 'algum treino precisa ter exercicios');
    final plan = await workouts.plan(chosenWorkoutId);
    expect(exercises.containsKey(plan.first.exerciseId), isTrue);

    // execucao: iniciar, registrar 2 series, editar, remover, finalizar
    final sessions = SessionRepository(dio);
    final before = await sessions.history(me.id);
    if (before.any((s) => s.workoutId == chosenWorkoutId && s.isOpen)) {
      final open = before.firstWhere((s) => s.workoutId == chosenWorkoutId && s.isOpen);
      await sessions.finish(open.id);
    }

    final started = await sessions.start(chosenWorkoutId);
    expect(started.isOpen, isTrue);
    await expectLater(
      sessions.start(chosenWorkoutId),
      throwsA(isA<AppException>().having((e) => e.statusCode, 'statusCode', 409)),
    );

    final itemId = plan.first.id;
    await sessions.addPerformance(started.id, workoutExerciseId: itemId, setNumber: 1, reps: 12, loadKg: 20);
    await sessions.addPerformance(started.id, workoutExerciseId: itemId, setNumber: 2, reps: 10);
    var current = await sessions.get(started.id);
    expect(current.setsOf(itemId).map((p) => p.setNumber), [1, 2]);
    expect(current.setsOf(itemId).last.loadKg, isNull);

    await sessions.updatePerformance(started.id, current.setsOf(itemId).last.id,
        setNumber: 2, reps: 9, loadKg: 22.5);
    await sessions.deletePerformance(started.id, current.setsOf(itemId).first.id);
    current = await sessions.get(started.id);
    expect(current.setsOf(itemId), hasLength(1));
    expect(current.setsOf(itemId).single.reps, 9);
    expect(current.setsOf(itemId).single.loadKg, 22.5);

    await sessions.finish(started.id);
    final after = await sessions.history(me.id);
    final finished = after.firstWhere((s) => s.id == started.id);
    expect(finished.isOpen, isFalse);
    await expectLater(
      sessions.addPerformance(started.id, workoutExerciseId: itemId, setNumber: 3, reps: 1),
      throwsA(isA<AppException>().having((e) => e.statusCode, 'statusCode', 409)),
    );

    expect(unauthorizedCalls, 0);
  });

  test('credenciais erradas viram AppException 401 com mensagem do servidor', skip: skip, () async {
    final dio = buildDio(storage: InMemoryTokenStorage(), onUnauthorized: () {});
    await expectLater(
      AuthRepository(dio).login(email, 'senha-errada-123'),
      throwsA(isA<AppException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.message, 'message', isNotEmpty)),
    );
  });

  test('token invalido: 401 limpa o armazenamento e avisa a sessao', skip: skip, () async {
    final storage = InMemoryTokenStorage(StoredSessionFactory.valid('token-invalido'));
    var unauthorizedCalls = 0;
    final dio = buildDio(storage: storage, onUnauthorized: () => unauthorizedCalls++);

    await expectLater(AuthRepository(dio).me(), throwsA(isA<AppException>()));

    expect(unauthorizedCalls, 1);
    expect(storage.session, isNull);
  });

  test('conta de PERSONAL e recusada pelo app (controller real + API real)', skip: skip, () async {
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [tokenStorageProvider.overrideWithValue(InMemoryTokenStorage())],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await expectLater(
      container.read(authControllerProvider.notifier).login(trainerEmail, password),
      throwsA(isA<AppException>().having((e) => e.message, 'message', contains('exclusivo para alunos'))),
    );

    expect(container.read(tokenStorageProvider).read(), completion(isNull));
  });

  test('controller real: login do aluno, historico e execucao pelo provider', skip: skip, () async {
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [tokenStorageProvider.overrideWithValue(InMemoryTokenStorage())],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).login(email, password);
    expect(container.read(authControllerProvider).value?.email, email);

    final history = await container.read(historyProvider.future);
    expect(history, isA<List>());
  });
}
