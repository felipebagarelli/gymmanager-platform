import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/features/account/application/account_providers.dart';
import 'package:gymmanager_mobile/features/account/data/account_repository.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/auth/domain/student_profile.dart';
import 'package:gymmanager_mobile/features/billing/application/billing_providers.dart';
import 'package:gymmanager_mobile/features/billing/data/billing_repository.dart';
import 'package:gymmanager_mobile/features/billing/domain/billing.dart';
import 'package:gymmanager_mobile/features/chat/application/chat_providers.dart';
import 'package:gymmanager_mobile/features/home/application/home_tab_provider.dart';
import 'package:gymmanager_mobile/features/home/presentation/home_page.dart';
import 'package:gymmanager_mobile/features/profile/presentation/profile_page.dart';
import 'package:gymmanager_mobile/features/sessions/presentation/history_page.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';
import 'package:gymmanager_mobile/features/workouts/data/workout_repository.dart';
import 'package:gymmanager_mobile/features/workouts/domain/workout.dart';

import 'support/fake_chat.dart';
import 'support/fake_repositories.dart';
import 'support/fakes.dart';

final _now = DateTime(2026, 10, 10, 12);

class _FakeBilling extends BillingRepository {
  _FakeBilling(this.subscription) : super(Dio());

  final Subscription? subscription;
  AppException? regularizeError;
  int fetches = 0;
  int regularizeCalls = 0;

  @override
  Future<Subscription?> mySubscription() async {
    fetches++;
    return subscription;
  }

  @override
  Future<String> regularize() async {
    regularizeCalls++;
    if (regularizeError != null) throw regularizeError!;
    return 'https://pay.example/invoice';
  }

  @override
  Future<List<Plan>> availablePlans() async => const [];
}

class _FakeAccount extends AccountRepository {
  _FakeAccount() : super(Dio());

  final deleted = <String>[];
  final updates = <Map<String, Object?>>[];

  @override
  Future<LegalInfo> legal() async => const LegalInfo(termsVersion: 'v1', termsUrl: 'https://example.com/termos');

  @override
  Future<void> deleteMyAccount(String password) async {
    if (password != 'certa') throw AppException('Senha incorreta.', statusCode: 400);
    deleted.add(password);
  }

  @override
  Future<void> updateStudentData({required String name, String? phone, double? height, double? weight}) async =>
      updates.add({'name': name, 'phone': phone, 'height': height, 'weight': weight});
}

class _Blocked402Workouts extends FakeWorkoutRepository {
  @override
  Future<List<Workout>> myWorkouts(int studentId) async =>
      throw AppException('Sua mensalidade está em atraso.', statusCode: 402);
}

class _FixedTab extends HomeTabController {
  _FixedTab(this.initial);
  final int initial;
  @override
  int build() => initial;
}

WorkoutSession _session(int id, DateTime start, double load) => WorkoutSession(
      id: id,
      workoutId: 10,
      startedAt: start,
      finishedAt: start.add(const Duration(minutes: 40)),
      performances: [Performance(id: id, workoutExerciseId: 100, setNumber: 1, reps: 10, loadKg: load)],
    );

const _profile = StudentProfile(
  id: 2,
  email: 'maria@example.com',
  name: 'Maria Aluna',
  goal: 'Hipertrofia',
  height: 1.7,
  weight: 62.5,
);

final _pastDue = Subscription(
  id: 1,
  status: SubscriptionStatus.pastDue,
  planName: 'Plano Mensal',
  priceCents: 18000,
  currentPeriodEnd: DateTime(2026, 10, 1),
);

final _active = Subscription(
  id: 1,
  status: SubscriptionStatus.active,
  planName: 'Plano Mensal',
  priceCents: 18000,
  currentPeriodEnd: DateTime(2026, 11, 15),
);

Widget _app({
  Subscription? subscription,
  int tab = HomeTab.workouts,
  List<WorkoutSession> sessions = const [],
  WorkoutRepository? workouts,
  _FakeBilling? billing,
  List<String>? opened,
  _FakeAccount? account,
}) {
  final List<Override> overrides = [
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage(StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)))),
    ),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository(profile: _profile)),
    workoutRepositoryProvider.overrideWithValue(workouts ?? FakeWorkoutRepository()),
    sessionRepositoryProvider.overrideWithValue(FakeSessionRepository(initial: sessions)),
    chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
    chatPollIntervalProvider.overrideWithValue(const Duration(hours: 1)),
    chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
    billingRepositoryProvider.overrideWithValue(billing ?? _FakeBilling(subscription)),
    urlOpenerProvider.overrideWithValue((url) async {
      opened?.add(url);
      return true;
    }),
    clockProvider.overrideWithValue(() => _now),
    accountRepositoryProvider.overrideWithValue(account ?? _FakeAccount()),
    homeTabProvider.overrideWith(() => _FixedTab(tab)),
  ];
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: overrides,
    child: MaterialApp(theme: AppTheme.dark(), home: const HomePage()),
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
}

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

Finder _stat(String key, String value) => find.descendant(of: find.byKey(Key(key)), matching: find.text(value));

void main() {
  group('Perfil', () {
    testWidgets('cabeçalho, números do histórico e plano', (tester) async {
      await _pump(
        tester,
        _app(
          tab: HomeTab.profile,
          subscription: _active,
          sessions: [
            _session(1, DateTime(2026, 9, 21, 9), 40),
            _session(2, DateTime(2026, 10, 5, 9), 45), // bate o recorde de carga
          ],
        ),
      );

      expect(_text(tester, 'profile-name'), 'MARIA ALUNA');
      expect(find.text('Aluno de João Personal'), findsOneWidget);
      expect(_stat('stat-workouts', '2'), findsOneWidget);
      expect(_stat('stat-weeks', '1'), findsOneWidget); // semana de 28/9 sem treino quebra a sequência
      expect(_stat('stat-records', '1'), findsOneWidget);
      expect(find.text('Plano Mensal'), findsOneWidget);
      expect(_text(tester, 'subscription-status'), 'Ativo');
      expect(_text(tester, 'plan-price'), 'R\$ 180,00');
      expect(find.text('Renova em 15/11'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('sem histórico os números mostram zero', (tester) async {
      await _pump(tester, _app(tab: HomeTab.profile, subscription: _active));

      expect(_stat('stat-workouts', '0'), findsOneWidget);
      expect(_stat('stat-weeks', '0'), findsOneWidget);
      expect(_stat('stat-records', '0'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('menu: o que ainda não existe fica "Em breve"; Dados pessoais abre os dados', (tester) async {
      await _pump(tester, _app(tab: HomeTab.profile, subscription: _active));

      expect(find.text('Em breve'), findsOneWidget);
      expect(find.text('Notificações'), findsOneWidget);
      expect(find.text('Privacidade e termos'), findsOneWidget);

      await tester.tap(find.byKey(const Key('menu-personal-data')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('personal-data')), findsOneWidget);
      expect(find.text('maria@example.com'), findsOneWidget);
      expect(find.text('Hipertrofia'), findsOneWidget);
      expect(find.text('1,7 m'), findsOneWidget);
      expect(find.text('62.5 kg'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('corrigir os dados manda nome, telefone, altura e peso', (tester) async {
      final account = _FakeAccount();
      await _pump(tester, _app(tab: HomeTab.profile, subscription: _active, account: account));

      await tester.tap(find.byKey(const Key('menu-personal-data')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-personal-data')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('edit-phone')), '11 99999-0000');
      await tester.enterText(find.byKey(const Key('edit-weight')), '64,0');
      await tester.enterText(find.byKey(const Key('edit-height')), '3');
      await tester.tap(find.byKey(const Key('save-data')));
      await tester.pumpAndSettle();
      expect(find.text('Altura em metros, entre 0,9 e 2,5.'), findsOneWidget);
      expect(account.updates, isEmpty);

      await tester.enterText(find.byKey(const Key('edit-height')), '1,72');
      await tester.tap(find.byKey(const Key('save-data')));
      await tester.pumpAndSettle();
      expect(account.updates.single, {'name': 'Maria Aluna', 'phone': '11 99999-0000', 'height': 1.72, 'weight': 64.0});
      await _close(tester);
    });

    testWidgets('Privacidade e termos abre o documento publicado', (tester) async {
      final opened = <String>[];
      await _pump(tester, _app(tab: HomeTab.profile, subscription: _active, opened: opened));

      await tester.tap(find.byKey(const Key('menu-legal')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-terms')));
      await tester.pumpAndSettle();
      expect(opened, ['https://example.com/termos']);

      // política ainda não publicada: avisa
      await tester.tap(find.byKey(const Key('menu-legal')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-privacy')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Documento em preparação'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('Excluir conta pede a senha e sai do app', (tester) async {
      final account = _FakeAccount();
      await _pump(tester, _app(tab: HomeTab.profile, subscription: _active, account: account));

      await tester.tap(find.byKey(const Key('menu-delete-account')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('delete-account-password')), 'errada');
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm-delete-account')));
      await tester.pumpAndSettle();
      expect(find.text('Senha incorreta.'), findsOneWidget);
      expect(find.byKey(const Key('profile-name')), findsOneWidget);

      await tester.tap(find.byKey(const Key('menu-delete-account')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('delete-account-password')), 'certa');
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm-delete-account')));
      await tester.pumpAndSettle();
      expect(account.deleted, ['certa']);
      expect(find.byKey(const Key('profile-name')), findsNothing);
      await _close(tester);
    });

    testWidgets('Sair limpa a sessão', (tester) async {
      await _pump(tester, _app(tab: HomeTab.profile, subscription: _active));
      expect(find.byKey(const Key('profile-name')), findsOneWidget);

      await tester.tap(find.byKey(const Key('logout')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('profile-name')), findsNothing);
      await _close(tester);
    });
  });

  group('abas sob demanda', () {
    testWidgets('Histórico e Perfil só são construídos na primeira visita (e mantidos depois)', (tester) async {
      await _pump(tester, _app(subscription: _active));

      expect(find.byType(HistoryPage, skipOffstage: false), findsNothing);
      expect(find.byType(ProfilePage, skipOffstage: false), findsNothing);

      await tester.tap(find.text('Histórico'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(HistoryPage), findsOneWidget);
      expect(find.byType(ProfilePage, skipOffstage: false), findsNothing);

      await tester.tap(find.text('Perfil'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ProfilePage), findsOneWidget);
      // voltando, o Histórico continua construído (mantém o estado)
      expect(find.byType(HistoryPage, skipOffstage: false), findsOneWidget);
      await _close(tester);
    });
  });

  group('Mensalidade em atraso', () {
    testWidgets('bloqueia Treinos com a tela de atraso e mostra plano e vencimento', (tester) async {
      await _pump(tester, _app(subscription: _pastDue));

      expect(_text(tester, 'overdue-title'), 'MENSALIDADE EM ATRASO');
      expect(
        _text(tester, 'overdue-message'),
        'Seus treinos e o chat com João Personal ficam bloqueados até regularizar. Seu histórico continua disponível.',
      );
      expect(find.text('Venceu em 01/10'), findsOneWidget);
      expect(find.text('R\$ 180,00'), findsOneWidget);
      expect(find.textContaining('BORA'), findsNothing); // a home de treinos não aparece
      await _close(tester);
    });

    testWidgets('em dia, Treinos aparece normalmente', (tester) async {
      await _pump(tester, _app(subscription: _active));

      expect(find.byKey(const Key('overdue-title')), findsNothing);
      expect(find.textContaining('BORA'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('sem assinatura (aluno cadastrado pelo personal) não é bloqueado', (tester) async {
      await _pump(tester, _app());

      expect(find.byKey(const Key('overdue-title')), findsNothing);
      await _close(tester);
    });

    testWidgets('Mensagens também mostra a tela de atraso, sem o campo de texto', (tester) async {
      await _pump(tester, _app(subscription: _pastDue, tab: HomeTab.messages));

      expect(find.byKey(const Key('overdue-title')), findsOneWidget);
      expect(find.byKey(const Key('chat-input')), findsNothing);
      await _close(tester);
    });

    testWidgets('"Ver histórico" leva ao Histórico e o Perfil segue acessível', (tester) async {
      await _pump(tester, _app(subscription: _pastDue));

      await tester.tap(find.byKey(const Key('overdue-history')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('HISTÓRICO'), findsOneWidget);
      expect(find.byKey(const Key('overdue-title')), findsNothing);

      await tester.tap(find.text('Perfil'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('profile-name')), findsOneWidget);
      expect(_text(tester, 'subscription-status'), 'Em atraso');
      expect(find.byKey(const Key('overdue-notice')), findsOneWidget);
      await _close(tester);
    });

    testWidgets('"Regularizar pagamento" abre a página de pagamento da cobrança em aberto', (tester) async {
      final billing = _FakeBilling(_pastDue);
      final opened = <String>[];
      await _pump(tester, _app(billing: billing, opened: opened));

      await tester.tap(find.byKey(const Key('regularize-payment')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(billing.regularizeCalls, 1);
      expect(opened, ['https://pay.example/invoice']);
      await _close(tester);
    });

    testWidgets('erro do servidor ao regularizar aparece como mensagem', (tester) async {
      final billing = _FakeBilling(_pastDue)
        ..regularizeError = AppException('Ainda não há cobrança em aberto para pagar. Tente novamente em instantes.', statusCode: 409);
      final opened = <String>[];
      await _pump(tester, _app(billing: billing, opened: opened));

      await tester.tap(find.byKey(const Key('regularize-payment')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Ainda não há cobrança em aberto'), findsOneWidget);
      expect(opened, isEmpty);
      await _close(tester);
    });

    testWidgets('ao voltar do navegador (app retomado) a assinatura é consultada de novo', (tester) async {
      final billing = _FakeBilling(_pastDue);
      await _pump(tester, _app(billing: billing));
      final before = billing.fetches;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 200));

      expect(billing.fetches, greaterThan(before));
      await _close(tester);
    });

    testWidgets('no Perfil, a assinatura em atraso também oferece "Regularizar pagamento"', (tester) async {
      final billing = _FakeBilling(_pastDue);
      final opened = <String>[];
      await _pump(tester, _app(tab: HomeTab.profile, billing: billing, opened: opened));

      await tester.tap(find.byKey(const Key('regularize-payment')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(opened, ['https://pay.example/invoice']);
      await _close(tester);
    });

    testWidgets('resposta 402 da API também mostra a tela de atraso', (tester) async {
      await _pump(tester, _app(subscription: _active, workouts: _Blocked402Workouts()));

      expect(find.byKey(const Key('overdue-title')), findsOneWidget);
      await _close(tester);
    });
  });
}
