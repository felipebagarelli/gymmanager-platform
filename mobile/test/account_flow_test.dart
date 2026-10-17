import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/routing/app_router.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/features/account/application/account_providers.dart';
import 'package:gymmanager_mobile/features/account/data/account_repository.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/billing/application/billing_providers.dart';
import 'package:gymmanager_mobile/features/chat/application/chat_providers.dart';
import 'package:gymmanager_mobile/features/home/presentation/home_page.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';

import 'support/fake_chat.dart';
import 'support/fake_repositories.dart';
import 'support/fakes.dart';

/// Servidor de contas em memória: guarda o que foi pedido.
class FakeAccountRepository extends AccountRepository {
  FakeAccountRepository({this.guardianPending = false}) : super(Dio());

  final bool guardianPending;
  final calls = <String>[];
  SignupDraft? lastDraft;
  AppException? verifyError;

  @override
  Future<LegalInfo> legal() async => const LegalInfo(termsVersion: 'v1', termsUrl: 'https://gymmanager.test/termos');

  @override
  Future<bool> register(SignupDraft draft) async {
    calls.add('register:${draft.email}');
    lastDraft = draft;
    return draft.guardianEmail != null;
  }

  @override
  Future<VerifyResult> verifyEmail(String email, String code) async {
    calls.add('verify:$email:$code');
    if (verifyError != null) throw verifyError!;
    return VerifyResult(guardianPending: guardianPending, guardianEmail: guardianPending ? 'an***@example.com' : null);
  }

  @override
  Future<void> resendVerification(String email) async => calls.add('resendVerification:$email');

  @override
  Future<void> resendGuardian(String email) async => calls.add('resendGuardian:$email');

  @override
  Future<void> forgotPassword(String email) async => calls.add('forgot:$email');

  @override
  Future<void> resetPassword(String email, String code, String newPassword) async =>
      calls.add('reset:$email:$code:${newPassword.length}');
}

Widget _app(FakeAccountRepository account, FakeAuthRepository auth, {List<String>? opened}) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
        authRepositoryProvider.overrideWithValue(auth),
        accountRepositoryProvider.overrideWithValue(account),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        urlOpenerProvider.overrideWithValue((url) async {
          opened?.add(url);
          return true;
        }),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 16, 12)),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(theme: AppTheme.dark(), routerConfig: ref.watch(routerProvider)),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _fillSignup(WidgetTester tester, {required String birth}) async {
  await tester.enterText(find.byKey(const Key('signup-name')), 'Maria Aluna');
  await tester.enterText(find.byKey(const Key('signup-email')), 'maria@example.com');
  await tester.enterText(find.byKey(const Key('signup-password')), 'senhaSegura123');
  await tester.enterText(find.byKey(const Key('signup-confirm')), 'senhaSegura123');
  await tester.enterText(find.byKey(const Key('signup-birth')), birth);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cadastro de adulto: aceites, código por e-mail e já entra no app', (tester) async {
    final account = FakeAccountRepository();
    final auth = FakeAuthRepository();
    final opened = <String>[];
    await _pump(tester, _app(account, auth, opened: opened));

    await _tap(tester, find.byKey(const Key('create-account')));
    expect(find.byKey(const Key('signup-name')), findsOneWidget);
    await _fillSignup(tester, birth: '21/03/1995');
    expect(find.byKey(const Key('guardian-section')), findsNothing);

    // sem os aceites não envia
    await _tap(tester, find.byKey(const Key('signup-submit')));
    expect(find.textContaining('marque as duas autorizações'), findsOneWidget);
    expect(account.calls, isEmpty);

    await _tap(tester, find.text('Termos de uso'));
    expect(opened, ['https://gymmanager.test/termos']);

    await _tap(tester, find.descendant(of: find.byKey(const Key('accept-terms')), matching: find.byType(Checkbox)));
    await _tap(tester, find.descendant(of: find.byKey(const Key('accept-health')), matching: find.byType(Checkbox)));
    await _tap(tester, find.byKey(const Key('signup-submit')));

    expect(account.calls, ['register:maria@example.com']);
    expect(account.lastDraft!.termsVersion, 'v1');
    expect(account.lastDraft!.guardianEmail, isNull);
    expect(find.text('CONFIRME SEU E-MAIL'), findsOneWidget);
    expect(find.textContaining('maria@example.com'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('verify-code')), '123456');
    await _tap(tester, find.byKey(const Key('verify-submit')));

    expect(account.calls, contains('verify:maria@example.com:123456'));
    expect(auth.loginCalls, 1);
    expect(find.byType(HomePage), findsOneWidget);
    await _close(tester);
  });

  testWidgets('menor de 12 anos não consegue se cadastrar', (tester) async {
    final account = FakeAccountRepository();
    await _pump(tester, _app(account, FakeAuthRepository()));
    await _tap(tester, find.byKey(const Key('create-account')));

    await _fillSignup(tester, birth: '01/01/2016');
    await _tap(tester, find.descendant(of: find.byKey(const Key('accept-terms')), matching: find.byType(Checkbox)));
    await _tap(tester, find.descendant(of: find.byKey(const Key('accept-health')), matching: find.byType(Checkbox)));
    await _tap(tester, find.byKey(const Key('signup-submit')));

    expect(find.text('É preciso ter pelo menos 12 anos'), findsOneWidget);
    expect(account.calls, isEmpty);
    await _close(tester);
  });

  testWidgets('de 12 a 17 anos: pede o responsável e, depois do código, espera a autorização', (tester) async {
    final account = FakeAccountRepository(guardianPending: true);
    final auth = FakeAuthRepository();
    await _pump(tester, _app(account, auth));
    await _tap(tester, find.byKey(const Key('create-account')));

    await _fillSignup(tester, birth: '10/05/2011');
    expect(find.byKey(const Key('guardian-section')), findsOneWidget);
    expect(find.textContaining('15 anos'), findsOneWidget);

    await _tap(tester, find.descendant(of: find.byKey(const Key('accept-terms')), matching: find.byType(Checkbox)));
    await _tap(tester, find.descendant(of: find.byKey(const Key('accept-health')), matching: find.byType(Checkbox)));
    await _tap(tester, find.byKey(const Key('signup-submit')));
    expect(find.text('Informe o nome do responsável'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('guardian-name')), 'Ana Souza');
    await tester.enterText(find.byKey(const Key('guardian-email')), 'maria@example.com');
    await _tap(tester, find.byKey(const Key('signup-submit')));
    expect(find.text('Precisa ser diferente do seu e-mail'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('guardian-email')), 'ana@example.com');
    await _tap(tester, find.byKey(const Key('signup-submit')));
    expect(account.lastDraft!.guardianEmail, 'ana@example.com');

    await tester.enterText(find.byKey(const Key('verify-code')), '654321');
    await _tap(tester, find.byKey(const Key('verify-submit')));

    expect(find.text('FALTA O RESPONSÁVEL'), findsOneWidget);
    expect(find.textContaining('an***@example.com'), findsOneWidget);
    expect(auth.loginCalls, 0);

    await _tap(tester, find.byKey(const Key('guardian-resend')));
    expect(account.calls, contains('resendGuardian:maria@example.com'));
    await _close(tester);
  });

  testWidgets('login com e-mail não confirmado leva ao código e reenvia', (tester) async {
    final account = FakeAccountRepository();
    final auth = FakeAuthRepository(
      loginError: AppException('Confirme seu e-mail.', statusCode: 403, code: 'EMAIL_NOT_VERIFIED'),
    );
    await _pump(tester, _app(account, auth));

    await tester.enterText(find.byKey(const Key('email')), 'maria@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'senhaSegura123');
    await _tap(tester, find.byKey(const Key('login-button')));

    expect(find.text('CONFIRME SEU E-MAIL'), findsOneWidget);
    expect(account.calls, ['resendVerification:maria@example.com']);
    expect(find.byKey(const Key('verify-info')), findsOneWidget);

    // sem a senha (veio do login): confirma e volta para entrar
    await tester.enterText(find.byKey(const Key('verify-code')), '111222');
    await _tap(tester, find.byKey(const Key('verify-submit')));
    expect(find.text('E-mail confirmado. Entre com sua senha.'), findsOneWidget);
    expect(find.byKey(const Key('login-button')), findsOneWidget);
    await _close(tester);
  });

  testWidgets('login de quem espera o responsável mostra o aviso', (tester) async {
    final auth = FakeAuthRepository(
      loginError: AppException('Falta a autorização.', statusCode: 403, code: 'GUARDIAN_CONSENT_PENDING'),
    );
    await _pump(tester, _app(FakeAccountRepository(), auth));

    await tester.enterText(find.byKey(const Key('email')), 'pedro@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'senhaSegura123');
    await _tap(tester, find.byKey(const Key('login-button')));

    expect(find.byKey(const Key('guardian-pending')), findsOneWidget);
    await _close(tester);
  });

  testWidgets('esqueci a senha: código por e-mail e senha nova', (tester) async {
    final account = FakeAccountRepository();
    await _pump(tester, _app(account, FakeAuthRepository()));

    await tester.enterText(find.byKey(const Key('email')), 'maria@example.com');
    await _tap(tester, find.byKey(const Key('forgot-password')));
    // já vem com o e-mail digitado no login
    await _tap(tester, find.byKey(const Key('reset-send')));
    expect(account.calls, ['forgot:maria@example.com']);
    expect(find.text('NOVA SENHA'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reset-code')), '123');
    await tester.enterText(find.byKey(const Key('reset-password')), 'curta');
    await _tap(tester, find.byKey(const Key('reset-submit')));
    expect(find.text('O código tem 6 números'), findsOneWidget);
    expect(find.text('A senha precisa ter pelo menos 8 caracteres'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reset-code')), '987654');
    await tester.enterText(find.byKey(const Key('reset-password')), 'novaSenha123');
    await tester.enterText(find.byKey(const Key('reset-confirm')), 'novaSenha123');
    await _tap(tester, find.byKey(const Key('reset-submit')));

    expect(account.calls, contains('reset:maria@example.com:987654:12'));
    expect(find.text('Senha alterada. Entre com a nova senha.'), findsOneWidget);
    expect(find.byKey(const Key('login-button')), findsOneWidget);
    await _close(tester);
  });

  group('repositório de conta', () {
    test('envia o cadastro com a data no formato da API e lê o código de erro', () async {
      final requests = <RequestOptions>[];
      var status = 201;
      var body = '{"email":"maria@example.com","guardianRequired":true}';
      final dio = Dio()..httpClientAdapter = _Adapter((o) {
          requests.add(o);
          return (status, body);
        });
      final repo = AccountRepository(dio);

      final guardian = await repo.register(SignupDraft(
        name: ' Pedro ',
        email: 'pedro@example.com ',
        password: 'senhaSegura123',
        birthDate: DateTime(2011, 5, 9),
        termsVersion: 'v1',
        guardianName: 'Ana',
        guardianEmail: 'ana@example.com',
      ));
      expect(guardian, isTrue);
      final sent = requests.last.data;
      final json = (sent is String ? jsonDecode(sent) : sent) as Map<String, dynamic>;
      expect(json['birthDate'], '2011-05-09');
      expect(json['email'], 'pedro@example.com');
      expect(json['acceptTerms'], isTrue);
      expect(json['acceptHealthData'], isTrue);

      status = 403;
      body = '{"status":403,"message":"Confirme seu e-mail.","code":"EMAIL_NOT_VERIFIED"}';
      await expectLater(
        repo.verifyEmail('pedro@example.com', '123456'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'EMAIL_NOT_VERIFIED')),
      );
    });

    test('idade completa', () {
      expect(ageOn(DateTime(2011, 10, 17), DateTime(2026, 10, 16)), 14);
      expect(ageOn(DateTime(2011, 10, 16), DateTime(2026, 10, 16)), 15);
    });
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final (int, String) Function(RequestOptions options) respond;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final (status, body) = respond(options);
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}
