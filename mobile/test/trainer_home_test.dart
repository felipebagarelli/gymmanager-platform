import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/routing/app_router.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/home/presentation/home_page.dart';
import 'package:gymmanager_mobile/features/trainer/presentation/trainer_home_page.dart';

import 'support/fakes.dart';

/// App inteiro (roteador real) com a sessão guardada de um papel.
Widget _app(InMemoryTokenStorage storage) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(theme: AppTheme.dark(), routerConfig: ref.watch(routerProvider)),
      ),
    );

InMemoryTokenStorage _session(String role) =>
    InMemoryTokenStorage(StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)), role: role));

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('personal logado abre o modo personal, com as abas do personal', (tester) async {
    await _pump(tester, _app(_session('TRAINER')));

    expect(find.byType(TrainerHomePage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    for (final label in ['Alunos', 'Treinos', 'Mensagens', 'Planos', 'Perfil']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    // abas do aluno não aparecem para o personal
    expect(find.text('Histórico'), findsNothing);
    expect(find.text('Personal IA'), findsNothing);
  });

  testWidgets('perfil do personal mostra nome e contato; sair volta para o login', (tester) async {
    final storage = _session('TRAINER');
    await _pump(tester, _app(storage));

    await tester.tap(find.text('Perfil'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('JOÃO PERSONAL'), findsOneWidget);
    expect(find.text('joao@example.com'), findsOneWidget);
    expect(find.text('11 99999-0000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('trainer-logout')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(storage.session, isNull);
    expect(find.byKey(const Key('login-button')), findsOneWidget);
  });

  testWidgets('personal não entra nas telas de execução de treino do aluno', (tester) async {
    await _pump(tester, _app(_session('TRAINER')));
    final container = ProviderScope.containerOf(tester.element(find.byType(TrainerHomePage)));

    container.read(routerProvider).go('/workouts/10/run');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(TrainerHomePage), findsOneWidget);
  });

  testWidgets('aluno logado continua abrindo o app do aluno', (tester) async {
    await _pump(tester, _app(_session('STUDENT')));

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(TrainerHomePage), findsNothing);
  });

  testWidgets('aluno não entra nas telas do personal', (tester) async {
    await _pump(tester, _app(_session('STUDENT')));
    final container = ProviderScope.containerOf(tester.element(find.byType(HomePage)));

    container.read(routerProvider).go('/trainer/students/2');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(HomePage), findsOneWidget);
  });
}
