import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';
import 'package:gymmanager_mobile/features/sessions/presentation/completion_page.dart';
import 'package:gymmanager_mobile/features/sessions/presentation/execute_workout_page.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';
import 'package:gymmanager_mobile/features/workouts/data/workout_repository.dart';
import 'package:gymmanager_mobile/features/workouts/domain/workout.dart';

import 'support/fake_repositories.dart';
import 'support/fakes.dart';

/// Relógio e pulso de 1 s controlados pelo teste (nada de Timer real).
class FakeTime {
  DateTime now = DateTime(2026, 10, 9, 10);
  final ticks = StreamController<void>.broadcast(sync: true);

  void advance(int seconds) {
    now = now.add(Duration(seconds: seconds));
    ticks.add(null);
  }
}

Widget buildApp(FakeSessionRepository sessions, FakeTime time, {WorkoutRepository? workouts}) {
  final router = GoRouter(
    initialLocation: '/workouts/10/run',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('home-page'))),
      GoRoute(
        path: '/workouts/:id/run',
        builder: (context, state) => ExecuteWorkoutPage(workoutId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/workouts/:id/done',
        builder: (context, state) => CompletionPage(workoutId: int.parse(state.pathParameters['id']!)),
      ),
    ],
  );
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage(StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)))),
      ),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      workoutRepositoryProvider.overrideWithValue(workouts ?? FakeWorkoutRepository()),
      sessionRepositoryProvider.overrideWithValue(sessions),
      clockProvider.overrideWithValue(() => time.now),
      secondTickerProvider.overrideWithValue(time.ticks.stream),
    ],
    child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
}

Finder progress(int itemId, String text) => find.descendant(
      of: find.byKey(Key('progress-$itemId')),
      matching: find.text(text),
      matchRoot: true,
    );

Future<void> openSheet(WidgetTester tester, int itemId) async {
  await tester.tap(find.byKey(Key('add-set-$itemId')));
  await tester.pumpAndSettle();
}

Future<void> fillSheet(WidgetTester tester, {required String reps, required String load}) async {
  await tester.enterText(find.byKey(const Key('set-reps')), reps);
  await tester.enterText(find.byKey(const Key('set-load')), load);
}

Future<void> saveSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('set-save')));
  await tester.pumpAndSettle();
}

/// Registra uma série e volta do descanso para a execução.
Future<void> registerSet(WidgetTester tester, int itemId, {required String reps, required String load}) async {
  await openSheet(tester, itemId);
  await fillSheet(tester, reps: reps, load: load);
  await saveSheet(tester);
  if (find.byKey(const Key('rest-skip')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('rest-skip')));
    await tester.pumpAndSettle();
  }
}

/// O plano do treino 11 (que aparece no histórico) não carrega: simula falha de rede ao finalizar.
class _PlanOfWorkout11Fails extends FakeWorkoutRepository {
  @override
  Future<List<PlanItem>> plan(int workoutId) async {
    if (workoutId == 11) throw AppException('Sem conexão com o servidor. Tente novamente.');
    return super.plan(workoutId);
  }
}

void main() {
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    // o ponto do cronômetro pisca em loop; sem isso o pumpAndSettle nunca terminaria
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  Future<FakeSessionRepository> startedRepository() async {
    final repository = FakeSessionRepository();
    await repository.start(10);
    return repository;
  }

  testWidgets('sem sessão iniciada, oferece iniciar e abre o primeiro exercício', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildApp(FakeSessionRepository(), FakeTime()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('start-workout')), findsOneWidget);
    expect(find.byKey(const Key('finish-workout')), findsNothing);

    await tester.tap(find.byKey(const Key('start-workout')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('active-100')), findsOneWidget);
    expect(find.text('0 de 7 séries'), findsOneWidget);
    expect(progress(100, '0/3'), findsOneWidget);
    // o outro exercício aparece compacto, com grupo e contagem em texto
    expect(find.byKey(const Key('compact-101')), findsOneWidget);
    expect(progress(101, 'Pernas · 0/4'), findsOneWidget);
  });

  testWidgets('registrar série: sheet pré-preenchido, salvar guarda o "Como foi?" e abre o descanso', (tester) async {
    useTallScreen(tester);
    final repository = await startedRepository();
    await tester.pumpWidget(buildApp(repository, FakeTime()));
    await tester.pumpAndSettle();

    await openSheet(tester, 100);
    // vem preenchido com a meta do exercício (12 reps, 20 kg)
    expect(find.widgetWithText(TextField, '12'), findsOneWidget);
    expect(find.widgetWithText(TextField, '20'), findsOneWidget);

    // cancelar não registra nada
    await tester.tap(find.byKey(const Key('set-cancel')));
    await tester.pumpAndSettle();
    expect(progress(100, '0/3'), findsOneWidget);

    await openSheet(tester, 100);
    await fillSheet(tester, reps: '10', load: '22,5');
    await tester.tap(find.byKey(const Key('effort-HARD')));
    await saveSheet(tester);

    final saved = repository.sessions.single.performances.single;
    expect(saved.reps, 10);
    expect(saved.loadKg, 22.5);
    expect(saved.effort, Effort.hard);
    expect(repository.calls, contains('add:100#1'));

    // abre o descanso do exercício (60 s) com a próxima série
    expect(find.byKey(const Key('rest-time')), findsOneWidget);
    expect(find.text('01:00'), findsOneWidget);
    expect(find.text('Série 1 de Supino salva · 10 × 22,5 kg'), findsOneWidget);
    expect(find.text('Supino · Série 2'), findsOneWidget);
  });

  testWidgets('"Como foi?" é opcional: sem escolher, nada é enviado; tocar de novo desmarca', (tester) async {
    useTallScreen(tester);
    final repository = await startedRepository();
    await tester.pumpWidget(buildApp(repository, FakeTime()));
    await tester.pumpAndSettle();

    await openSheet(tester, 100);
    await tester.tap(find.byKey(const Key('effort-EASY')));
    await tester.tap(find.byKey(const Key('effort-EASY')));
    await saveSheet(tester);

    expect(repository.sessions.single.performances.single.effort, isNull);
  });

  testWidgets('steppers mudam repetições (±1) e carga (±2,5); carga 0 vira "sem carga"', (tester) async {
    useTallScreen(tester);
    final repository = await startedRepository();
    await tester.pumpWidget(buildApp(repository, FakeTime()));
    await tester.pumpAndSettle();

    await openSheet(tester, 100);
    await tester.tap(find.byKey(const Key('reps-plus')));
    await tester.tap(find.byKey(const Key('load-plus')));
    await tester.pump();
    expect(find.widgetWithText(TextField, '13'), findsOneWidget);
    expect(find.widgetWithText(TextField, '22,5'), findsOneWidget);

    await fillSheet(tester, reps: '8', load: '0');
    await saveSheet(tester);

    final saved = repository.sessions.single.performances.single;
    expect(saved.reps, 8);
    expect(saved.loadKg, isNull);
  });

  testWidgets('valor inválido no sheet mostra erro e não salva', (tester) async {
    useTallScreen(tester);
    final repository = await startedRepository();
    await tester.pumpWidget(buildApp(repository, FakeTime()));
    await tester.pumpAndSettle();

    await openSheet(tester, 100);
    await fillSheet(tester, reps: '', load: '20');
    await tester.tap(find.byKey(const Key('set-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('set-error')), findsOneWidget);
    expect(repository.sessions.single.performances, isEmpty);
  });

  testWidgets('descanso: conta pelo relógio, ±15 s ajusta e ao zerar volta sozinho para o treino', (tester) async {
    useTallScreen(tester);
    final time = FakeTime();
    final repository = await startedRepository();
    await tester.pumpWidget(buildApp(repository, time));
    await tester.pumpAndSettle();

    await registerSetKeepingRest(tester);
    expect(find.text('01:00'), findsOneWidget);

    time.advance(10);
    await tester.pump();
    expect(find.text('00:50'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rest-plus')));
    await tester.pump();
    expect(find.text('01:05'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rest-minus')));
    await tester.pump();
    expect(find.text('00:50'), findsOneWidget);

    time.advance(50);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rest-time')), findsNothing);
    expect(progress(100, '1/3'), findsOneWidget);
  });

  testWidgets('pular o descanso volta para o treino', (tester) async {
    useTallScreen(tester);
    final repository = await startedRepository();
    await tester.pumpWidget(buildApp(repository, FakeTime()));
    await tester.pumpAndSettle();

    await registerSetKeepingRest(tester);
    await tester.tap(find.byKey(const Key('rest-skip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rest-time')), findsNothing);
    expect(progress(100, '1/3'), findsOneWidget);
    expect(find.text('1 de 7 séries'), findsOneWidget);
  });

  testWidgets('editar e remover uma série feita', (tester) async {
    useTallScreen(tester);
    final repository = await startedRepository();
    await repository.addPerformance(500, workoutExerciseId: 100, setNumber: 1, reps: 12, loadKg: 20);
    await tester.pumpWidget(buildApp(repository, FakeTime()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('set-900')));
    await tester.pumpAndSettle();
    await fillSheet(tester, reps: '9', load: '25');
    await saveSheet(tester);
    expect(repository.sessions.single.performances.single.reps, 9);
    expect(find.text('9 reps × 25 kg'), findsOneWidget);
    // editar não abre descanso
    expect(find.byKey(const Key('rest-time')), findsNothing);

    await tester.tap(find.byKey(const Key('set-900')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('set-remove')));
    await tester.pumpAndSettle();
    expect(repository.sessions.single.performances, isEmpty);
    expect(progress(100, '0/3'), findsOneWidget);
  });

  testWidgets('trocar de exercício pelo card compacto', (tester) async {
    useTallScreen(tester);
    final repository = await startedRepository();
    await tester.pumpWidget(buildApp(repository, FakeTime()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('compact-101')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('active-101')), findsOneWidget);
    expect(find.byKey(const Key('compact-100')), findsOneWidget);
  });

  testWidgets('finalizar com séries pendentes pede confirmação e leva ao resumo', (tester) async {
    useTallScreen(tester);
    final repository = await startedRepository();
    await tester.pumpWidget(buildApp(repository, FakeTime()));
    await tester.pumpAndSettle();
    await registerSet(tester, 100, reps: '10', load: '22,5');

    await tester.tap(find.byKey(const Key('finish-workout')));
    await tester.pumpAndSettle();
    expect(find.text('Finalizar treino?'), findsOneWidget);
    expect(find.textContaining('Faltam 6 séries'), findsOneWidget);

    // "Voltar" não finaliza
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(repository.sessions.single.isOpen, isTrue);

    await tester.tap(find.byKey(const Key('finish-workout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-finish')));
    await tester.pumpAndSettle();

    expect(repository.sessions.single.isOpen, isFalse);
    expect(find.text('TREINO CONCLUÍDO'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('kpi-sets')), matching: find.textContaining('1/7'), matchRoot: true), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('kpi-volume')), matching: find.textContaining('225'), matchRoot: true), findsOneWidget);
  });

  testWidgets('todas as séries feitas: finaliza direto, sem confirmação', (tester) async {
    useTallScreen(tester);
    final repository = await startedRepository();
    for (var n = 1; n <= 3; n++) {
      await repository.addPerformance(500, workoutExerciseId: 100, setNumber: n, reps: 12, loadKg: 20);
    }
    for (var n = 1; n <= 4; n++) {
      await repository.addPerformance(500, workoutExerciseId: 101, setNumber: n, reps: 10, loadKg: 30);
    }
    await tester.pumpWidget(buildApp(repository, FakeTime()));
    await tester.pumpAndSettle();
    expect(find.text('7 de 7 séries'), findsOneWidget);

    await tester.tap(find.byKey(const Key('finish-workout')));
    await tester.pumpAndSettle();

    expect(find.text('Finalizar treino?'), findsNothing);
    expect(find.text('TREINO CONCLUÍDO'), findsOneWidget);
  });

  testWidgets('erro do servidor ao registrar aparece como mensagem e não altera a tela', (tester) async {
    useTallScreen(tester);
    final repository = await startedRepository();
    await tester.pumpWidget(buildApp(repository, FakeTime()));
    await tester.pumpAndSettle();

    repository.failWith = AppException('Esta sessão já foi finalizada.', statusCode: 409);
    await openSheet(tester, 100);
    await saveSheet(tester);

    expect(find.text('Esta sessão já foi finalizada.'), findsOneWidget);
    expect(progress(100, '0/3'), findsOneWidget);
    expect(find.byKey(const Key('rest-time')), findsNothing);
  });

  testWidgets('retoma uma sessão em andamento sem pedir para iniciar de novo', (tester) async {
    useTallScreen(tester);
    final repository = await startedRepository();
    await repository.addPerformance(500, workoutExerciseId: 100, setNumber: 1, reps: 12, loadKg: 20);
    await tester.pumpWidget(buildApp(repository, FakeTime()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('start-workout')), findsNothing);
    expect(find.text('12 reps × 20 kg'), findsOneWidget);
    expect(progress(100, '1/3'), findsOneWidget);
  });

  testWidgets('falha de rede ao preparar o resumo: mostra a mensagem e a sessão continua aberta', (tester) async {
    useTallScreen(tester);
    final repository = FakeSessionRepository(initial: [
      WorkoutSession(
        id: 400,
        workoutId: 11,
        startedAt: DateTime(2026, 10, 1, 10),
        finishedAt: DateTime(2026, 10, 1, 11),
        performances: const [Performance(id: 1, workoutExerciseId: 100, setNumber: 1, reps: 10, loadKg: 20)],
      ),
    ]);
    await repository.start(10);
    await tester.pumpWidget(buildApp(repository, FakeTime(), workouts: _PlanOfWorkout11Fails()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('finish-workout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-finish')));
    await tester.pumpAndSettle();

    // o erro do plano chega embrulhado pelo Riverpod: o aluno vê a mensagem genérica e pode tentar de novo
    expect(find.text('Algo deu errado. Tente novamente.'), findsOneWidget);
    expect(repository.sessions.last.isOpen, isTrue);
    expect(find.byKey(const Key('finish-workout')), findsOneWidget);
    expect(find.text('TREINO CONCLUÍDO'), findsNothing);
  });

  testWidgets('cronômetro mostra o tempo desde o início e acompanha o relógio', (tester) async {
    useTallScreen(tester);
    final time = FakeTime();
    final repository = FakeSessionRepository(initial: [
      WorkoutSession(id: 500, workoutId: 10, startedAt: time.now.subtract(const Duration(minutes: 5, seconds: 30))),
    ]);
    await tester.pumpWidget(buildApp(repository, time));
    await tester.pumpAndSettle();
    expect(find.text('05:30'), findsOneWidget);

    time.advance(31);
    await tester.pump();
    expect(find.text('06:01'), findsOneWidget);
  });
}

/// Registra a série padrão (valores do sheet) e deixa o descanso aberto.
Future<void> registerSetKeepingRest(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('add-set-100')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('set-save')));
  await tester.pumpAndSettle();
}
