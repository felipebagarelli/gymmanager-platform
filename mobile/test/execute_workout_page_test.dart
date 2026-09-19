import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/sessions/presentation/execute_workout_page.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';

import 'support/fake_repositories.dart';
import 'support/fakes.dart';

Widget buildApp(FakeSessionRepository sessions) {
  final router = GoRouter(
    initialLocation: '/run',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('home-page'))),
      GoRoute(path: '/run', builder: (context, state) => const ExecuteWorkoutPage(workoutId: 10)),
    ],
  );
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage(
          StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1))),
        ),
      ),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
      sessionRepositoryProvider.overrideWithValue(sessions),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Finder progress(int itemId, String text) => find.descendant(
      of: find.byKey(Key('progress-$itemId')),
      matching: find.text(text),
    );

Future<void> registerSet(WidgetTester tester, int itemId, {required String reps, required String load}) async {
  await tester.tap(find.byKey(Key('add-set-$itemId')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('set-reps')), reps);
  await tester.enterText(find.byKey(const Key('set-load')), load);
  await tester.tap(find.byKey(const Key('set-save')));
  await tester.pumpAndSettle();
}

void main() {
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('antes de iniciar, mostra o plano e o botao Iniciar treino', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildApp(FakeSessionRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Supino'), findsOneWidget);
    expect(find.text('Agachamento'), findsOneWidget);
    expect(find.text('3 x 12 · 20 kg · descanso 60s'), findsOneWidget);
    expect(find.byKey(const Key('start-workout')), findsOneWidget);
    expect(find.byKey(const Key('finish-workout')), findsNothing);
  });

  testWidgets('fluxo completo: iniciar, registrar, remover e finalizar', (tester) async {
    useTallScreen(tester);
    final repository = FakeSessionRepository();
    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-workout')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('finish-workout')), findsOneWidget);
    expect(progress(100, '0/3'), findsOneWidget);

    // o diálogo já vem preenchido com a meta do exercício
    await tester.tap(find.byKey(const Key('add-set-100')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '12'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '20'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(progress(100, '0/3'), findsOneWidget);

    await registerSet(tester, 100, reps: '10', load: '22,5');
    expect(find.text('10 repetições · 22.5 kg'), findsOneWidget);
    expect(progress(100, '1/3'), findsOneWidget);
    expect(repository.calls, contains('add:100#1'));

    await registerSet(tester, 100, reps: '9', load: '');
    expect(find.text('9 repetições · —'), findsOneWidget);
    expect(progress(100, '2/3'), findsOneWidget);

    await tester.tap(find.byTooltip('Remover série').first);
    await tester.pumpAndSettle();
    expect(find.text('10 repetições · 22.5 kg'), findsNothing);
    expect(progress(100, '1/3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('finish-workout')));
    await tester.pumpAndSettle();
    expect(find.text('Finalizar treino?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-finish')));
    await tester.pumpAndSettle();

    expect(find.text('home-page'), findsOneWidget);
    expect(find.text('Treino finalizado! Bom trabalho.'), findsOneWidget);
    expect(repository.sessions.single.isOpen, isFalse);
  });

  testWidgets('erro do servidor ao registrar aparece como mensagem e nao altera a tela', (tester) async {
    useTallScreen(tester);
    final repository = FakeSessionRepository();
    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-workout')));
    await tester.pumpAndSettle();

    repository.failWith = AppException('Esta sessão já foi finalizada.', statusCode: 409);
    await registerSet(tester, 100, reps: '10', load: '20');

    expect(find.text('Esta sessão já foi finalizada.'), findsOneWidget);
    expect(progress(100, '0/3'), findsOneWidget);
  });

  testWidgets('retoma uma sessao em andamento sem pedir para iniciar de novo', (tester) async {
    useTallScreen(tester);
    final repository = FakeSessionRepository();
    await repository.start(10);
    await repository.addPerformance(500, workoutExerciseId: 100, setNumber: 1, reps: 12, loadKg: 20);
    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('start-workout')), findsNothing);
    expect(find.text('12 repetições · 20 kg'), findsOneWidget);
    expect(progress(100, '1/3'), findsOneWidget);
  });
}
