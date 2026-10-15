import 'dart:convert';
import 'dart:typed_data';

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
import 'package:gymmanager_mobile/features/billing/application/billing_providers.dart';
import 'package:gymmanager_mobile/features/billing/domain/billing.dart';
import 'package:gymmanager_mobile/features/chat/application/chat_providers.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/trainer/plans/application/trainer_billing_providers.dart';
import 'package:gymmanager_mobile/features/trainer/plans/data/trainer_billing_repository.dart';
import 'package:gymmanager_mobile/features/trainer/students/application/students_providers.dart';
import 'package:gymmanager_mobile/features/trainer/students/domain/managed_student.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';

import 'support/fake_chat.dart';
import 'support/fake_repositories.dart';
import 'support/fakes.dart';
import 'trainer_students_test.dart' show FakeStudentsRepository;

/// Planos, assinaturas e conta de recebimento em memória.
class FakeTrainerBillingRepository extends TrainerBillingRepository {
  FakeTrainerBillingRepository({
    List<Plan>? plans,
    List<Subscription>? subscriptions,
    this.account = const PayoutAccount(connected: false, chargesEnabled: false),
  })  : planList = [...?plans],
        subscriptionList = [...?subscriptions],
        super(Dio());

  final List<Plan> planList;
  final List<Subscription> subscriptionList;
  PayoutAccount account;
  final calls = <String>[];
  AppException? payoutError;
  int _next = 900;

  @override
  Future<List<Plan>> plans() async => [...planList]..sort((a, b) => a.priceCents.compareTo(b.priceCents));

  @override
  Future<Plan> createPlan(PlanDraft draft) async {
    calls.add('createPlan:${draft.name}:${draft.priceCents}:${draft.description}');
    final plan = Plan(id: _next++, name: draft.name, priceCents: draft.priceCents, description: draft.description);
    planList.add(plan);
    return plan;
  }

  @override
  Future<Plan> updatePlan(int planId, PlanDraft draft) async {
    calls.add('updatePlan:$planId:${draft.name}:${draft.priceCents}:${draft.active}');
    final i = planList.indexWhere((p) => p.id == planId);
    planList[i] = Plan(id: planId, name: draft.name, priceCents: draft.priceCents, description: draft.description, active: draft.active);
    return planList[i];
  }

  @override
  Future<List<Subscription>> subscriptions() async => [...subscriptionList];

  @override
  Future<PayoutAccount> payoutAccount() async {
    calls.add('payoutAccount');
    if (payoutError != null) throw payoutError!;
    return account;
  }

  @override
  Future<String> startOnboarding() async {
    calls.add('startOnboarding');
    return 'https://connect.stripe.test/setup/abc';
  }
}

Subscription _sub(int id, int studentId, String name, SubscriptionStatus status,
        {int planId = 1, String plan = 'Mensal', int price = 15000, DateTime? end}) =>
    Subscription(
      id: id,
      status: status,
      planName: plan,
      priceCents: price,
      currentPeriodEnd: end,
      planId: planId,
      studentId: studentId,
      studentName: name,
    );

const _plans = [
  Plan(id: 1, name: 'Mensal', priceCents: 15000, description: '3 treinos por semana'),
  Plan(id: 2, name: 'Premium', priceCents: 25000),
];

List<Subscription> _subs() => [
      // mais recentes primeiro, como a API devolve
      _sub(13, 2, 'Maria Aluna', SubscriptionStatus.active, end: DateTime(2026, 11, 5)),
      _sub(12, 3, 'Bruno Silva', SubscriptionStatus.pastDue, planId: 2, plan: 'Premium', price: 25000),
      _sub(11, 4, 'Carla Souza', SubscriptionStatus.canceled, end: DateTime(2026, 9, 1)),
      _sub(10, 2, 'Maria Aluna', SubscriptionStatus.canceled), // assinatura antiga da Maria
    ];

Widget _app(FakeTrainerBillingRepository billing, List<String> opened) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(
          StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)), role: 'TRAINER'),
        )),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        chatRepositoryProvider.overrideWithValue(FakeTrainerChatRepository([])),
        chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
        trainerBillingRepositoryProvider.overrideWithValue(billing),
        studentsRepositoryProvider.overrideWithValue(FakeStudentsRepository([
          const ManagedStudent(id: 2, email: 'maria@example.com', name: 'Maria Aluna', active: true),
          const ManagedStudent(id: 3, email: 'bruno@example.com', name: 'Bruno Silva', active: true),
        ])),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        urlOpenerProvider.overrideWithValue((url) async {
          opened.add(url);
          return true;
        }),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 15, 12)),
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
  await _tap(tester, find.text('Planos'));
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

Finder _in(String key, Finder matching) => find.descendant(of: find.byKey(Key(key)), matching: matching);

/// Responde conforme o caminho e guarda as requisições (contrato com a API).
class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String Function(RequestOptions options) body = (_) => '{}';

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(body(options), 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('valores', () {
    test('formatPrice separa milhares; parsePriceCents aceita os jeitos comuns de digitar', () {
      expect(formatPrice(125000), 'R\$ 1.250,00');
      expect(formatPrice(1000000000), 'R\$ 10.000.000,00');
      expect(parsePriceCents('150'), 15000);
      expect(parsePriceCents('150,5'), 15050);
      expect(parsePriceCents('1.250,00'), 125000);
      expect(parsePriceCents('1.250'), 125000);
      expect(parsePriceCents('R\$ 99,90'), 9990);
      expect(parsePriceCents('99.90'), 9990);
      expect(parsePriceCents(''), isNull);
      expect(parsePriceCents('abc'), isNull);
    });

    test('vale a assinatura mais recente de cada aluno; atraso primeiro', () {
      final current = currentSubscriptions(_subs());

      expect(current.map((s) => s.id), [12, 13, 11]);
      final summary = BillingSummary.from(current);
      expect(summary.active, 1);
      expect(summary.overdue, 1);
      expect(summary.canceled, 1);
      expect(summary.monthlyCents, 15000);
      expect(subscribersOf(1, current), 1);
      expect(subscribersOf(2, current), 1);
    });
  });

  group('repositório', () {
    test('lê planos e assinaturas da visão do personal e envia o plano em centavos', () async {
      final adapter = _Adapter();
      final repo = TrainerBillingRepository(Dio()..httpClientAdapter = adapter);

      adapter.body = (_) => '[{"id":1,"name":"Mensal","description":null,"priceCents":15000,"active":false}]';
      expect((await repo.plans()).single.active, isFalse);

      adapter.body = (_) => '[{"id":5,"status":"PAST_DUE","planId":1,"planName":"Mensal","priceCents":15000,'
          '"currentPeriodEnd":null,"studentId":2,"studentName":"Maria"}]';
      final sub = (await repo.subscriptions()).single;
      expect(adapter.requests.last.path, '/api/v1/billing/subscriptions');
      expect(sub.status, SubscriptionStatus.pastDue);
      expect(sub.studentName, 'Maria');

      adapter.body = (_) => '{"id":1,"name":"Mensal","priceCents":16000,"active":true}';
      await repo.updatePlan(1, const PlanDraft(name: ' Mensal ', priceCents: 16000, description: '  '));
      expect(adapter.requests.last.method, 'PUT');
      final sent = adapter.requests.last.data;
      expect((sent is String ? jsonDecode(sent) : sent), {'name': 'Mensal', 'priceCents': 16000, 'description': null, 'active': true});

      adapter.body = (_) => '{"url":"https://connect.stripe.test/x"}';
      expect(await repo.startOnboarding(), 'https://connect.stripe.test/x');
      expect(adapter.requests.last.path, '/api/v1/billing/payout-account/onboarding');
    });
  });

  group('aba Planos', () {
    testWidgets('sem recebimento configurado: explica e abre o cadastro no navegador', (tester) async {
      final billing = FakeTrainerBillingRepository(plans: _plans);
      final opened = <String>[];
      await _pump(tester, _app(billing, opened));

      expect(find.byKey(const Key('payout-missing')), findsOneWidget);
      expect(find.textContaining('só conseguem assinar depois disso'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('payout-onboard')));

      expect(billing.calls, contains('startOnboarding'));
      expect(opened, ['https://connect.stripe.test/setup/abc']);
      await _close(tester);
    });

    testWidgets('cadastro incompleto: continuar ou verificar de novo', (tester) async {
      final billing = FakeTrainerBillingRepository(account: const PayoutAccount(connected: true, chargesEnabled: false));
      await _pump(tester, _app(billing, []));

      expect(find.byKey(const Key('payout-pending')), findsOneWidget);
      expect(_in('payout-onboard', find.text('CONTINUAR CADASTRO')), findsOneWidget);

      billing.account = const PayoutAccount(connected: true, chargesEnabled: true);
      await _tap(tester, find.byKey(const Key('payout-refresh')));

      expect(find.byKey(const Key('payout-enabled')), findsOneWidget);
      await _close(tester);
    });

    testWidgets('provedor fora do ar mostra o motivo sem derrubar a tela', (tester) async {
      final billing = FakeTrainerBillingRepository(plans: _plans)
        ..payoutError = AppException('Pagamentos indisponíveis no momento.', statusCode: 503);
      await _pump(tester, _app(billing, []));

      expect(find.byKey(const Key('payout-error')), findsOneWidget);
      expect(find.text('Pagamentos indisponíveis no momento.'), findsOneWidget);
      expect(find.byKey(const Key('plan-1')), findsOneWidget);
      await _close(tester);
    });

    testWidgets('números do mês, planos com assinantes e assinaturas com filtro', (tester) async {
      final billing = FakeTrainerBillingRepository(
        plans: _plans,
        subscriptions: _subs(),
        account: const PayoutAccount(connected: true, chargesEnabled: true),
      );
      await _pump(tester, _app(billing, []));

      expect(_in('monthly-revenue', find.text('R\$ 150,00')), findsOneWidget);
      expect(_in('stat-overdue', find.text('1')), findsOneWidget);
      expect(_in('plan-1', find.text('1 assinante')), findsOneWidget);
      expect(_in('plan-1', find.text('3 treinos por semana')), findsOneWidget);
      expect(_in('subscription-13', find.textContaining('Renova em 05')), findsOneWidget);
      expect(_in('subscription-12', find.text('Em atraso')), findsOneWidget);
      expect(find.byKey(const Key('subscription-10')), findsNothing); // histórico da Maria

      await _tap(tester, find.byKey(const Key('stat-overdue')));
      expect(find.byKey(const Key('subscription-12')), findsOneWidget);
      expect(find.byKey(const Key('subscription-13')), findsNothing);

      await _tap(tester, find.byKey(const Key('subs-filter-all')));
      await _tap(tester, find.byKey(const Key('subscription-13')));
      expect(find.byKey(const Key('student-name')), findsOneWidget);
      expect(find.text('MARIA ALUNA'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('criar plano valida nome e valor e envia em centavos', (tester) async {
      final billing = FakeTrainerBillingRepository();
      await _pump(tester, _app(billing, []));

      expect(find.byKey(const Key('no-plans')), findsOneWidget);
      await _tap(tester, find.text('Novo'));
      await tester.enterText(find.byKey(const Key('plan-price')), '0,50');
      await _tap(tester, find.byKey(const Key('plan-save')));
      expect(find.text('Dê um nome ao plano'), findsOneWidget);
      expect(find.text('O valor mínimo é R\$ 1,00'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('plan-name')), 'Mensal 2x');
      await tester.enterText(find.byKey(const Key('plan-price')), '1.250,50');
      await tester.enterText(find.byKey(const Key('plan-description')), 'Duas aulas por semana');
      await _tap(tester, find.byKey(const Key('plan-save')));

      expect(billing.calls, contains('createPlan:Mensal 2x:125050:Duas aulas por semana'));
      expect(find.text('R\$ 1.250,50'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('editar: mudar o valor avisa quem já assina; desativar esconde para novos', (tester) async {
      final billing = FakeTrainerBillingRepository(plans: _plans, subscriptions: _subs());
      await _pump(tester, _app(billing, []));

      await _tap(tester, find.byKey(const Key('plan-1')));
      expect(find.text('EDITAR PLANO'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('plan-price')), '170');
      await tester.pumpAndSettle();
      expect(find.textContaining('Quem já assina continua pagando'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('plan-active')));
      await _tap(tester, find.byKey(const Key('plan-save')));

      expect(billing.calls, contains('updatePlan:1:Mensal:17000:false'));
      expect(_in('plan-1', find.text('Desativado')), findsOneWidget);
      await _close(tester);
    });
  });
}
