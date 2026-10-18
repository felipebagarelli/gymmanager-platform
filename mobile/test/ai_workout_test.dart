import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/routing/app_router.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/features/ai_workout/application/ai_workout_providers.dart';
import 'package:gymmanager_mobile/features/ai_workout/data/ai_workout_repository.dart';
import 'package:gymmanager_mobile/features/ai_workout/presentation/ai_workout_page.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/auth/domain/student_profile.dart';
import 'package:gymmanager_mobile/features/chat/application/chat_providers.dart';
import 'package:gymmanager_mobile/features/home/presentation/home_page.dart';
import 'package:gymmanager_mobile/features/onboarding/application/onboarding_providers.dart';
import 'package:gymmanager_mobile/features/onboarding/presentation/onboarding_page.dart';
import 'package:gymmanager_mobile/features/platform_plan/application/platform_plan_providers.dart';
import 'package:gymmanager_mobile/features/platform_plan/data/platform_plan_repository.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/trainer/workouts/application/trainer_workouts_providers.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';
import 'package:gymmanager_mobile/features/workouts/data/workout_repository.dart';
import 'package:gymmanager_mobile/features/workouts/domain/workout.dart';

import 'onboarding_test.dart' show FakeOnboardingRepository;
import 'platform_plan_test.dart' show FakePlatformPlanRepository;
import 'support/fake_chat.dart';
import 'support/fake_repositories.dart';
import 'support/fake_trainer_workouts.dart';
import 'support/fakes.dart';

class FakeAiWorkoutRepository extends AiWorkoutRepository {
  FakeAiWorkoutRepository({this.allowed = true, this.reasonCode, this.reason}) : super(Dio());

  bool allowed;
  String? reasonCode;
  String? reason;
  AppException? proposeError;
  final calls = <String>[];
  int _next = 1;

  @override
  Future<ProposalEligibility> eligibility() async => ProposalEligibility(
        allowed: allowed,
        reason: reason,
        reasonCode: reasonCode,
        usedThisMonth: 0,
        monthlyLimit: 1,
      );

  @override
  Future<WorkoutProposal> propose({String? note}) async {
    calls.add('propose:${note ?? ''}');
    if (proposeError != null) throw proposeError!;
    return WorkoutProposal(
      id: _next++,
      status: ProposalStatus.proposed,
      summary: 'Corpo inteiro, 3 vezes por semana.',
      workouts: const [
        ProposedWorkout(name: 'Treino A - Corpo inteiro', exercises: [
          ProposedExercise(name: 'Agachamento goblet', sets: 3, reps: 12, restSeconds: 60, note: 'Desça devagar'),
          ProposedExercise(name: 'Prancha (segundos)', sets: 2, reps: 30, restSeconds: 45),
        ]),
      ],
    );
  }

  @override
  Future<WorkoutProposal> proposeAdjustment(int workoutId, {String? note}) async {
    calls.add('adjust:$workoutId:${note ?? ''}');
    return WorkoutProposal(
      id: _next++,
      status: ProposalStatus.proposed,
      workouts: const [],
      adjustment: WorkoutAdjustment(
        summary: 'Você está pronto para progredir.',
        workoutId: workoutId,
        workoutName: 'Treino A - Corpo inteiro',
        changes: const [
          AdjustmentChange(
            swap: false,
            exerciseName: 'Agachamento goblet',
            setsBefore: 3, repsBefore: 12, restBefore: 60, loadBefore: 20,
            setsAfter: 3, repsAfter: 12, restAfter: 60, loadAfter: 22,
            note: 'Suba 2 kg',
          ),
          AdjustmentChange(
            swap: true,
            exerciseName: 'Flexão de braço',
            newExerciseName: 'Supino reto com halteres',
            setsBefore: 3, repsBefore: 10, restBefore: 60,
            setsAfter: 3, repsAfter: 10, restAfter: 60,
          ),
        ],
      ),
    );
  }

  @override
  Future<WorkoutProposal> accept(int id) async {
    calls.add('accept:$id');
    return WorkoutProposal(id: id, status: ProposalStatus.accepted, workouts: const [], workoutIds: const [50]);
  }

  @override
  Future<void> reject(int id) async => calls.add('reject:$id');
}

class _NoWorkouts extends WorkoutRepository {
  _NoWorkouts([this.items = const []]) : super(Dio());

  final List<Workout> items;

  @override
  Future<List<Workout>> myWorkouts(int studentId) async => items;

  @override
  Future<List<PlanItem>> plan(int workoutId) async => const [];

  @override
  Future<List<Exercise>> exercises() async => const [];
}

const _independent = StudentProfile(id: 9, email: 'ana@example.com', name: 'Ana Independente', hasTrainer: false);

PlatformPlanStatus _freePlan() => const PlatformPlanStatus(
      tier: PlanTier.free,
      monthlyCents: 1990,
      yearlyCents: 14990,
      trialDays: 7,
      trialAvailable: true,
      aiWorkoutsPerMonth: 1,
      canSubscribe: true,
    );

Widget _app(FakeAiWorkoutRepository ai, {List<Workout> workouts = const []}) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(
          StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)), role: 'STUDENT'),
        )),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(profile: _independent)),
        onboardingRepositoryProvider.overrideWithValue(FakeOnboardingRepository()),
        needsOnboardingProvider.overrideWithValue(false),
        aiWorkoutRepositoryProvider.overrideWithValue(ai),
        platformPlanRepositoryProvider.overrideWithValue(FakePlatformPlanRepository(_freePlan())),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
        workoutRepositoryProvider.overrideWithValue(_NoWorkouts(workouts)),
        trainerWorkoutsRepositoryProvider.overrideWithValue(FakeTrainerWorkoutsRepository(workouts: {})),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 18, 12)),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(theme: AppTheme.dark(), routerConfig: ref.watch(routerProvider)),
      ),
    );

Future<void> _pumpAi(WidgetTester tester, FakeAiWorkoutRepository ai) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(ai));
  await tester.pumpAndSettle();
  await _tap(tester, find.byKey(const Key('ai-first-workout')));
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

void main() {
  testWidgets('pede a proposta, vê a prévia com o aviso e aceita', (tester) async {
    final ai = FakeAiWorkoutRepository();
    await _pumpAi(tester, ai);

    expect(find.byType(AiWorkoutPage), findsOneWidget);
    expect(find.byKey(const Key('proposal-quota')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('proposal-note')), 'Mais foco em pernas');
    await _tap(tester, find.byKey(const Key('proposal-generate')));

    expect(ai.calls, ['propose:Mais foco em pernas']);
    expect(find.text('Corpo inteiro, 3 vezes por semana.'), findsOneWidget);
    expect(find.text('TREINO A - CORPO INTEIRO'), findsOneWidget);
    expect(find.text('3 × 12 · 60 s de descanso'), findsOneWidget);
    expect(find.text('2 × 30 s · 45 s de descanso'), findsOneWidget);
    expect(find.text('Desça devagar'), findsOneWidget);
    expect(find.text(proposalDisclaimer), findsOneWidget);

    await _tap(tester, find.byKey(const Key('proposal-accept')));
    expect(ai.calls, contains('accept:1'));
    expect(find.text('Treino criado! Ele já está na aba Treinos.'), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
    await _close(tester);
  });

  testWidgets('gerar outra descarta a anterior; descartar volta', (tester) async {
    final ai = FakeAiWorkoutRepository();
    await _pumpAi(tester, ai);

    await _tap(tester, find.byKey(const Key('proposal-generate')));
    await _tap(tester, find.byKey(const Key('proposal-again')));
    expect(ai.calls, ['propose:', 'reject:1', 'propose:']);

    await _tap(tester, find.byKey(const Key('proposal-discard')));
    expect(ai.calls.last, 'reject:2');
    expect(find.byType(AiWorkoutPage), findsNothing);
    await _close(tester);
  });

  testWidgets('pedido recusado pela IA aparece como mensagem, sem prévia', (tester) async {
    final ai = FakeAiWorkoutRepository()
      ..proposeError = AppException('Para dor no joelho, procure um fisioterapeuta.', statusCode: 400);
    await _pumpAi(tester, ai);

    await tester.enterText(find.byKey(const Key('proposal-note')), 'Treino para minha dor no joelho');
    await _tap(tester, find.byKey(const Key('proposal-generate')));

    expect(find.byKey(const Key('proposal-error')), findsOneWidget);
    expect(find.textContaining('fisioterapeuta'), findsOneWidget);
    expect(find.byKey(const Key('proposal-accept')), findsNothing);
    await _close(tester);
  });

  testWidgets('triagem com risco: explica e leva para rever a triagem', (tester) async {
    final ai = FakeAiWorkoutRepository(
      allowed: false,
      reasonCode: 'HEALTH_RISK',
      reason: 'Pela sua triagem de saúde, o app não monta treinos automáticos.',
    );
    await _pumpAi(tester, ai);

    expect(find.byKey(const Key('proposal-blocked')), findsOneWidget);
    expect(find.byKey(const Key('proposal-generate')), findsNothing);
    await _tap(tester, find.byKey(const Key('proposal-blocked-action')));
    expect(find.byType(OnboardingPage), findsOneWidget);
    await _close(tester);
  });

  testWidgets('proposta grátis do mês usada: leva ao Pro no Perfil', (tester) async {
    final ai = FakeAiWorkoutRepository(allowed: false, reasonCode: 'FREE_LIMIT', reason: 'Você já usou a proposta grátis deste mês.');
    await _pumpAi(tester, ai);

    await _tap(tester, find.byKey(const Key('proposal-blocked-action')));
    expect(find.byKey(const Key('platform-plan')), findsOneWidget);
    await _close(tester);
  });

  testWidgets('D4: ajusta o próprio treino pelo detalhe, com antes e depois', (tester) async {
    final ai = FakeAiWorkoutRepository();
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(ai, workouts: const [Workout(id: 10, name: 'Treino A - Corpo inteiro')]));
    await tester.pumpAndSettle();

    await _tap(tester, find.byKey(const Key('hero-start')));
    await _tap(tester, find.byKey(const Key('adjust-with-ai')));
    expect(find.text('AJUSTAR COM A IA'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('proposal-generate')));
    expect(ai.calls, ['adjust:10:']);
    expect(find.text('Antes: 3 × 12 · 60 s · 20 kg'), findsOneWidget);
    expect(find.text('Depois: 3 × 12 · 60 s · 22 kg'), findsOneWidget);
    expect(find.text('Trocar Flexão de braço'), findsOneWidget);
    expect(find.text('por Supino reto com halteres'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('proposal-accept')));
    expect(ai.calls, contains('accept:1'));
    expect(find.text('Ajustes aplicados ao treino.'), findsOneWidget);
    expect(find.byType(AiWorkoutPage), findsNothing);
    await _close(tester);
  });

  test('lê o ajuste da API', () {
    final p = WorkoutProposal.fromJson({
      'id': 4,
      'status': 'PROPOSED',
      'kind': 'ADJUSTMENT',
      'content': null,
      'workoutIds': [],
      'adjustment': {
        'summary': 'Progrida.',
        'workoutId': 10,
        'workoutName': 'Treino A',
        'changes': [
          {'action': 'PROGRESS', 'exerciseName': 'Goblet', 'setsBefore': 3, 'repsBefore': 12, 'restBefore': null,
           'loadBefore': 20.5, 'setsAfter': 4, 'repsAfter': 12, 'restAfter': 60, 'loadAfter': 22.5, 'note': ''},
        ],
      },
    });
    final change = p.adjustment!.changes.single;
    expect(change.before, '3 × 12 · 20,5 kg');
    expect(change.after, '4 × 12 · 60 s · 22,5 kg');
    expect(change.note, isNull);
    expect(p.workouts, isEmpty);
  });

  test('lê a proposta da API', () {
    final p = WorkoutProposal.fromJson({
      'id': 3,
      'status': 'ACCEPTED',
      'content': {
        'summary': ' ',
        'workouts': [
          {
            'name': 'Treino A - Superiores',
            'exercises': [
              {'name': 'Esteira (minutos)', 'sets': 1, 'reps': 10, 'restSeconds': 30, 'note': ''},
            ],
          },
        ],
      },
      'workoutIds': [7, 8],
    });
    expect(p.status, ProposalStatus.accepted);
    expect(p.summary, isNull);
    expect(p.workouts.single.exercises.single.summary, '1 × 10 min · 30 s de descanso');
    expect(p.workouts.single.exercises.single.note, isNull);
    expect(p.workoutIds, [7, 8]);
  });
}
