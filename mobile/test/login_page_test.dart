import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/auth/presentation/login_page.dart';

import 'support/fakes.dart';

Widget buildPage(FakeAuthRepository repository) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
      authRepositoryProvider.overrideWithValue(repository),
    ],
    child: const MaterialApp(home: LoginPage()),
  );
}

void main() {
  testWidgets('campos vazios mostram erros de validacao e nao chamam a API', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(buildPage(repository));

    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();

    expect(find.text('Informe o e-mail'), findsOneWidget);
    expect(find.text('Informe a senha'), findsOneWidget);
    expect(repository.loginCalls, 0);
  });

  testWidgets('e-mail sem arroba e rejeitado', (tester) async {
    await tester.pumpWidget(buildPage(FakeAuthRepository()));

    await tester.enterText(find.byKey(const Key('email')), 'invalido');
    await tester.enterText(find.byKey(const Key('password')), 'senha');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();

    expect(find.text('E-mail inválido'), findsOneWidget);
  });

  testWidgets('credenciais invalidas (401) mostram mensagem amigavel', (tester) async {
    final repository = FakeAuthRepository(
      loginError: AppException('E-mail ou senha inválidos!', statusCode: 401),
    );
    await tester.pumpWidget(buildPage(repository));

    await tester.enterText(find.byKey(const Key('email')), 'aluno@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'errada');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-error')), findsOneWidget);
    expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
  });

  testWidgets('conta de administração mostra que deve usar o painel web', (tester) async {
    await tester.pumpWidget(buildPage(FakeAuthRepository(role: 'PLATFORM_ADMIN')));

    await tester.enterText(find.byKey(const Key('email')), 'admin@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'senha');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Use o painel web'), findsOneWidget);
  });

  testWidgets('conta de personal entra normalmente (sem erro na tela de login)', (tester) async {
    final repository = FakeAuthRepository(role: 'TRAINER');
    await tester.pumpWidget(buildPage(repository));

    await tester.enterText(find.byKey(const Key('email')), 'joao@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'senha');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-error')), findsNothing);
    expect(repository.trainerMeCalls, 1);
  });
}
