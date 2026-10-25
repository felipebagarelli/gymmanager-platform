import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/routing/app_router.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/auth/domain/student_profile.dart';
import 'package:gymmanager_mobile/features/billing/application/billing_providers.dart';
import 'package:gymmanager_mobile/features/billing/domain/billing.dart';
import 'package:gymmanager_mobile/features/chat/application/chat_providers.dart';
import 'package:gymmanager_mobile/features/chat/domain/chat.dart';
import 'package:gymmanager_mobile/features/hub/application/hub_providers.dart';
import 'package:gymmanager_mobile/features/invite/application/invite_providers.dart';
import 'package:gymmanager_mobile/features/invite/data/invite_repository.dart';
import 'package:gymmanager_mobile/features/invite/presentation/share_invite_sheet.dart';
import 'package:gymmanager_mobile/features/onboarding/application/onboarding_providers.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';

import 'onboarding_test.dart' show FakeOnboardingRepository;
import 'support/fake_chat.dart';
import 'support/fake_hub.dart';
import 'support/fake_repositories.dart';
import 'support/fakes.dart';

class _FakeInvites extends InviteRepository {
  _FakeInvites() : super(Dio());

  final calls = <String>[];
  var code = 'k7m2p9x4ab';

  @override
  Future<InvitePreview> preview(String code) async {
    if (InviteRepository.normalize(code) != this.code) {
      throw AppException('Convite não encontrado. Peça um link novo ao seu personal.', statusCode: 404);
    }
    return InvitePreview(
      code: this.code,
      trainerName: 'João Personal',
      headline: 'Hipertrofia para iniciantes',
      city: 'São Paulo',
      state: 'SP',
      online: true,
      planName: 'Mensal',
      planDescription: '3 treinos por semana',
      priceCents: 15000,
    );
  }

  @override
  Future<String> accept(String code) async {
    calls.add('accept:$code');
    return 'https://checkout.stripe.test/convite';
  }

  @override
  Future<InviteLink> link(int planId) async {
    calls.add('link:$planId');
    return InviteLink(code: code, url: 'https://api.example.com/convite/$code');
  }

  @override
  Future<InviteLink> reset(int planId) async {
    calls.add('reset:$planId');
    code = 'novocodigo';
    return InviteLink(code: code, url: 'https://api.example.com/convite/$code');
  }
}

class _NoConversation extends FakeChatRepository {
  @override
  Future<List<ConversationSummary>> conversations() async => const [];
}

const _independent = StudentProfile(id: 9, email: 'ana@example.com', name: 'Ana', hasTrainer: false);
const _withTrainer = StudentProfile(id: 9, email: 'ana@example.com', name: 'Ana');

Widget _app(_FakeInvites invites, {bool loggedIn = true, StudentProfile profile = _independent, List<String>? opened}) =>
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(
          loggedIn ? StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)), role: 'STUDENT') : null,
        )),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(profile: profile)),
        onboardingRepositoryProvider.overrideWithValue(FakeOnboardingRepository()),
        needsOnboardingProvider.overrideWithValue(false),
        inviteRepositoryProvider.overrideWithValue(invites),
        hubRepositoryProvider.overrideWithValue(FakeHubRepository()),
        chatRepositoryProvider.overrideWithValue(_NoConversation()),
        chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        urlOpenerProvider.overrideWithValue((url) async {
          opened?.add(url);
          return true;
        }),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 25, 12)),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(theme: AppTheme.dark(), routerConfig: ref.watch(routerProvider)),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Future<void> _go(WidgetTester tester, String location) async {
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(routerProvider).go(location);
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('aluno sem personal abre o convite, vê o plano e assina', (tester) async {
    final invites = _FakeInvites();
    final opened = <String>[];
    await _pump(tester, _app(invites, opened: opened));
    await _go(tester, '/convite/k7m2p9x4ab');

    expect(find.text('JOÃO PERSONAL'), findsOneWidget);
    expect(find.text('Mensal'), findsOneWidget);
    expect(find.textContaining('150,00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-subscribe')));
    await tester.pumpAndSettle();

    expect(invites.calls, ['accept:k7m2p9x4ab']);
    expect(opened, ['https://checkout.stripe.test/convite']);
    await _close(tester);
  });

  testWidgets('quem ainda não entrou: o convite aparece logo depois do login', (tester) async {
    await _pump(tester, _app(_FakeInvites(), loggedIn: false));
    await _go(tester, '/convite/k7m2p9x4ab');
    expect(find.byKey(const Key('login-button')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('email')), 'ana@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'senha1234');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite-page')), findsOneWidget);
    // aberto uma vez: voltar ao início não traz o convite de novo
    await _go(tester, '/');
    expect(find.byKey(const Key('invite-page')), findsNothing);
    await _close(tester);
  });

  testWidgets('aluno que já tem personal não assina; código inválido explica', (tester) async {
    await _pump(tester, _app(_FakeInvites(), profile: _withTrainer));
    await _go(tester, '/convite/k7m2p9x4ab');
    expect(find.byKey(const Key('invite-has-trainer')), findsOneWidget);
    expect(find.byKey(const Key('invite-subscribe')), findsNothing);

    await _go(tester, '/convite/errado');
    expect(find.byKey(const Key('invite-error')), findsOneWidget);
    expect(find.textContaining('Convite não encontrado'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('"Tenho um código de convite" em Mensagens abre o convite', (tester) async {
    await _pump(tester, _app(_FakeInvites()));
    await tester.tap(find.text('Mensagens'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('enter-invite-code')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('invite-code-field')), '  K7M2P9X4AB ');
    await tester.tap(find.byKey(const Key('invite-code-open')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite-page')), findsOneWidget);
    await _close(tester);
  });

  testWidgets('personal compartilha o link do plano e pode trocar por um novo', (tester) async {
    final invites = _FakeInvites();
    final shared = <String>[];
    const plan = Plan(id: 50, name: 'Mensal', priceCents: 15000);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        inviteRepositoryProvider.overrideWithValue(invites),
        shareTextProvider.overrideWithValue((text) async => shared.add(text)),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(onPressed: () => showShareInviteSheet(context, plan: plan), child: const Text('abrir')),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('https://api.example.com/convite/k7m2p9x4ab'), findsOneWidget);
    await tester.tap(find.byKey(const Key('share-invite')));
    await tester.pumpAndSettle();
    expect(shared.single, contains('https://api.example.com/convite/k7m2p9x4ab'));
    expect(shared.single, contains('Mensal'));

    await tester.tap(find.byKey(const Key('reset-invite')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-reset-invite')));
    await tester.pumpAndSettle();
    expect(invites.calls, ['link:50', 'reset:50']);
    expect(find.text('https://api.example.com/convite/novocodigo'), findsOneWidget);
  });
}
