import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';

import 'support/fakes.dart';

ProviderContainer makeContainer(InMemoryTokenStorage storage, FakeAuthRepository repository) {
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('sem token guardado, o estado inicial e deslogado', () async {
    final container = makeContainer(InMemoryTokenStorage(), FakeAuthRepository());

    final profile = await container.read(authControllerProvider.future);

    expect(profile, isNull);
  });

  test('token valido guardado restaura a sessao carregando o perfil', () async {
    final storage = InMemoryTokenStorage(
      StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1))),
    );
    final container = makeContainer(storage, FakeAuthRepository());

    final profile = await container.read(authControllerProvider.future);

    expect(profile?.name, 'Maria Aluna');
  });

  test('token expirado e descartado e o usuario fica deslogado', () async {
    final storage = InMemoryTokenStorage(
      StoredSession(token: 't', expiresAt: DateTime.now().subtract(const Duration(minutes: 1))),
    );
    final container = makeContainer(storage, FakeAuthRepository());

    final profile = await container.read(authControllerProvider.future);

    expect(profile, isNull);
    expect(storage.session, isNull);
  });

  test('login de aluno guarda o token e expoe o perfil', () async {
    final storage = InMemoryTokenStorage();
    final container = makeContainer(storage, FakeAuthRepository());
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).login('aluno@example.com', 'senha');

    expect(container.read(authControllerProvider).value?.id, 2);
    expect(storage.session?.token, 'jwt-token');
    expect(storage.session!.isExpired, isFalse);
  });

  test('login de TRAINER e recusado e nenhum token e guardado', () async {
    final storage = InMemoryTokenStorage();
    final container = makeContainer(storage, FakeAuthRepository(role: 'TRAINER'));
    await container.read(authControllerProvider.future);

    await expectLater(
      container.read(authControllerProvider.notifier).login('t@example.com', 'senha'),
      throwsA(isA<AppException>().having((e) => e.message, 'message', contains('exclusivo para alunos'))),
    );

    expect(storage.session, isNull);
    expect(container.read(authControllerProvider).value, isNull);
  });

  test('erro de credenciais do servidor e propagado', () async {
    final container = makeContainer(
      InMemoryTokenStorage(),
      FakeAuthRepository(loginError: AppException('E-mail ou senha inválidos!', statusCode: 401)),
    );
    await container.read(authControllerProvider.future);

    await expectLater(
      container.read(authControllerProvider.notifier).login('a@b.com', 'errada'),
      throwsA(isA<AppException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('logout limpa o token e o perfil', () async {
    final storage = InMemoryTokenStorage();
    final container = makeContainer(storage, FakeAuthRepository());
    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).login('aluno@example.com', 'senha');

    await container.read(authControllerProvider.notifier).logout();

    expect(storage.session, isNull);
    expect(container.read(authControllerProvider).value, isNull);
  });
}
