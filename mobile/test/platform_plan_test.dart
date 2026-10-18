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
import 'package:gymmanager_mobile/features/chat/application/chat_providers.dart';
import 'package:gymmanager_mobile/features/onboarding/application/onboarding_providers.dart';
import 'package:gymmanager_mobile/features/onboarding/domain/onboarding.dart';
import 'package:gymmanager_mobile/features/platform_plan/application/platform_plan_providers.dart';
import 'package:gymmanager_mobile/features/platform_plan/data/platform_plan_repository.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';

import 'onboarding_test.dart' show FakeOnboardingRepository;
import 'support/fake_chat.dart';
import 'support/fake_repositories.dart';
import 'support/fakes.dart';

class FakePlatformPlanRepository extends PlatformPlanRepository {
  FakePlatformPlanRepository(this.current) : super(Dio());

  PlatformPlanStatus current;
  final calls = <String>[];
  AppException? subscribeError;

  @override
  Future<PlatformPlanStatus> status() async => current;

  @override
  Future<String> subscribe({required bool yearly}) async {
    calls.add('subscribe:${yearly ? 'yearly' : 'monthly'}');
    if (subscribeError != null) throw subscribeError!;
    return 'https://checkout.stripe.test/${yearly ? 'y' : 'm'}';
  }

  @override
  Future<void> cancel() async => calls.add('cancel');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<String> regularize() async {
    calls.add('regularize');
    return 'https://invoice.stripe.test/1';
  }
}

PlatformPlanStatus _free({bool trial = true, bool canSubscribe = true, String? reason}) => PlatformPlanStatus(
      tier: PlanTier.free,
      monthlyCents: 1990,
      yearlyCents: 14990,
      trialDays: 7,
      trialAvailable: trial,
      aiWorkoutsPerMonth: 1,
      canSubscribe: canSubscribe,
      unavailableReason: reason,
    );

PlatformPlanStatus _pro(PlatformSubStatus status, {bool cancel = false}) => PlatformPlanStatus(
      tier: status == PlatformSubStatus.pastDue ? PlanTier.free : PlanTier.pro,
      subscription: PlatformSubscriptionInfo(
        status: status,
        yearly: false,
        priceCents: 1990,
        currentPeriodEnd: DateTime(2026, 11, 18),
        trialEnd: status == PlatformSubStatus.trialing ? DateTime(2026, 10, 25) : null,
        cancelAtPeriodEnd: cancel,
      ),
      monthlyCents: 1990,
      yearlyCents: 14990,
      trialDays: 7,
      trialAvailable: false,
      canSubscribe: false,
      unavailableReason: 'Você já tem uma assinatura.',
    );

const _independent = StudentProfile(id: 9, email: 'ana@example.com', name: 'Ana Independente', hasTrainer: false);

FakeOnboardingRepository _done() => FakeOnboardingRepository(
      profile: const TrainingProfile(
        goal: TrainingGoal.health,
        level: TrainingLevel.beginner,
        daysPerWeek: 3,
        minutesPerSession: 45,
        location: TrainingLocation.gym,
      ),
      risk: false,
    );

Widget _app(FakePlatformPlanRepository plan, List<String> opened, {StudentProfile profile = _independent}) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(
          StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)), role: 'STUDENT'),
        )),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(profile: profile)),
        onboardingRepositoryProvider.overrideWithValue(_done()),
        platformPlanRepositoryProvider.overrideWithValue(plan),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        urlOpenerProvider.overrideWithValue((url) async {
          opened.add(url);
          return true;
        }),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 18, 12)),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(theme: AppTheme.dark(), routerConfig: ref.watch(routerProvider)),
      ),
    );

Future<void> _pumpProfile(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  await _tap(tester, find.text('Perfil'));
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

void main() {
  testWidgets('plano grátis mostra a oferta com teste e abre o checkout do anual', (tester) async {
    final repo = FakePlatformPlanRepository(_free());
    final opened = <String>[];
    await _pumpProfile(tester, _app(repo, opened));

    expect(_in('plan-tier', find.text('Grátis')), findsOneWidget);
    expect(find.byKey(const Key('plan-trial')), findsOneWidget);
    expect(find.text('ANUAL · R\$ 149,90 (−37%)'), findsOneWidget);
    expect(find.text('MENSAL · R\$ 19,90'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('plan-yearly')));
    expect(repo.calls, ['subscribe:yearly']);
    expect(opened, ['https://checkout.stripe.test/y']);
    await _close(tester);
  });

  testWidgets('quem não pode assinar vê o motivo, sem botões', (tester) async {
    final repo = FakePlatformPlanRepository(
      _free(canSubscribe: false, reason: 'Para menores de 18 anos, a assinatura depende da aprovação do responsável (em breve).'),
    );
    await _pumpProfile(tester, _app(repo, []));

    expect(find.byKey(const Key('plan-unavailable')), findsOneWidget);
    expect(find.textContaining('menores de 18'), findsOneWidget);
    expect(find.byKey(const Key('plan-yearly')), findsNothing);
    await _close(tester);
  });

  testWidgets('Pro em teste mostra até quando; cancelar pede confirmação', (tester) async {
    final repo = FakePlatformPlanRepository(_pro(PlatformSubStatus.trialing));
    await _pumpProfile(tester, _app(repo, []));

    expect(_in('plan-tier', find.text('Pro')), findsOneWidget);
    expect(find.textContaining('Teste grátis até 25'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('plan-cancel')));
    expect(find.textContaining('até o fim do período'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('confirm-cancel-pro')));
    expect(repo.calls, ['cancel']);
    await _close(tester);
  });

  testWidgets('cancelado no fim do período pode manter o Pro; em atraso abre o pagamento', (tester) async {
    final repo = FakePlatformPlanRepository(_pro(PlatformSubStatus.active, cancel: true));
    final opened = <String>[];
    await _pumpProfile(tester, _app(repo, opened));

    expect(find.textContaining('Cancelado: Pro até 18'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('plan-resume')));
    expect(repo.calls, ['resume']);
    await _close(tester);

    final late = FakePlatformPlanRepository(_pro(PlatformSubStatus.pastDue));
    await _pumpProfile(tester, _app(late, opened));
    expect(find.textContaining('Pagamento pendente'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('plan-regularize')));
    expect(opened, ['https://invoice.stripe.test/1']);
    await _close(tester);
  });

  testWidgets('erro ao assinar aparece como mensagem', (tester) async {
    final repo = FakePlatformPlanRepository(_free())
      ..subscribeError = AppException('Os pagamentos não estão disponíveis no momento.', statusCode: 503);
    await _pumpProfile(tester, _app(repo, []));

    await _tap(tester, find.byKey(const Key('plan-monthly')));
    expect(find.text('Os pagamentos não estão disponíveis no momento.'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('aluno com personal vê a mensalidade do personal, não o plano da plataforma', (tester) async {
    final repo = FakePlatformPlanRepository(_free());
    await _pumpProfile(tester, _app(repo, [], profile: testProfile));

    expect(find.byKey(const Key('platform-plan')), findsNothing);
    await _close(tester);
  });

  test('lê o plano da API', () {
    final s = PlatformPlanStatus.fromJson({
      'tier': 'PRO',
      'subscription': {
        'status': 'TRIALING',
        'interval': 'YEARLY',
        'priceCents': 14990,
        'currentPeriodEnd': '2026-10-25T12:00:00',
        'trialEnd': '2026-10-25T12:00:00',
        'cancelAtPeriodEnd': false,
      },
      'offer': {'monthlyCents': 1990, 'yearlyCents': 14990, 'trialDays': 7, 'trialAvailable': false},
      'aiWorkoutsPerMonth': null,
      'canSubscribe': false,
      'unavailableReason': 'Você já tem uma assinatura.',
    });
    expect(s.isPro, isTrue);
    expect(s.subscription!.yearly, isTrue);
    expect(s.subscription!.status, PlatformSubStatus.trialing);
    expect(s.aiWorkoutsPerMonth, isNull);
    expect(s.yearlySavingPercent, 37);
  });
}
