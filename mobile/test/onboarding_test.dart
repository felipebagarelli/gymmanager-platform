import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/routing/app_router.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/auth/domain/student_profile.dart';
import 'package:gymmanager_mobile/features/chat/application/chat_providers.dart';
import 'package:gymmanager_mobile/features/home/presentation/home_page.dart';
import 'package:gymmanager_mobile/features/onboarding/application/onboarding_providers.dart';
import 'package:gymmanager_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:gymmanager_mobile/features/onboarding/domain/onboarding.dart';
import 'package:gymmanager_mobile/features/onboarding/presentation/onboarding_page.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';

import 'support/fake_chat.dart';
import 'support/fake_repositories.dart';
import 'support/fakes.dart';

/// Onboarding em memória, como o servidor guardaria.
class FakeOnboardingRepository extends OnboardingRepository {
  FakeOnboardingRepository({this.profile, this.risk}) : super(Dio());

  TrainingProfile? profile;
  bool? risk;
  List<bool>? lastAnswers;
  int statusCalls = 0;

  @override
  Future<OnboardingStatus> status() async {
    statusCalls++;
    return OnboardingStatus(
      trainingProfile: profile,
      screeningRisk: risk,
      completed: profile != null && risk != null,
      aiWorkoutsAllowed: risk == false,
    );
  }

  @override
  Future<void> saveTrainingProfile(TrainingProfile p) async => profile = p;

  @override
  Future<bool> answerScreening(List<bool> answers) async {
    lastAnswers = answers;
    return risk = answers.contains(true);
  }
}

const _independent = StudentProfile(id: 9, email: 'ana@example.com', name: 'Ana Independente', hasTrainer: false);

Widget _app(FakeOnboardingRepository onboarding, {StudentProfile profile = _independent}) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(
          StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)), role: 'STUDENT'),
        )),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(profile: profile)),
        onboardingRepositoryProvider.overrideWithValue(onboarding),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 18, 12)),
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

Future<void> _next(WidgetTester tester) => _tap(tester, find.byKey(const Key('onboarding-next')));

bool _nextEnabled(WidgetTester tester) {
  final button = tester.widget(find.byKey(const Key('onboarding-next')));
  return (button as dynamic).onPressed != null;
}

Future<void> _answerAll(WidgetTester tester, {int? yesAt}) async {
  for (var i = 0; i < screeningQuestions.length; i++) {
    await _tap(tester, find.byKey(Key('answer-$i-${i == yesAt ? 'yes' : 'no'}')));
  }
}

void main() {
  testWidgets('aluno sem personal faz o onboarding antes de tudo e depois cai no app', (tester) async {
    final repo = FakeOnboardingRepository();
    await _pump(tester, _app(repo));

    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(_nextEnabled(tester), isFalse);

    await _tap(tester, find.byKey(const Key('goal-hypertrophy')));
    await _next(tester);
    await _tap(tester, find.byKey(const Key('level-beginner')));
    await _next(tester);
    await _tap(tester, find.byKey(const Key('days-4')));
    await _tap(tester, find.byKey(const Key('minutes-60')));
    await _next(tester);

    // em casa precisa marcar o equipamento
    await _tap(tester, find.byKey(const Key('location-home')));
    expect(_nextEnabled(tester), isFalse);
    await _tap(tester, find.byKey(const Key('equipment-dumbbells')));
    await _tap(tester, find.byKey(const Key('equipment-bands')));
    await _next(tester);

    await tester.enterText(find.byKey(const Key('onboarding-height')), '3');
    await _next(tester);
    expect(find.byKey(const Key('onboarding-error')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('onboarding-height')), '1,68');
    await tester.enterText(find.byKey(const Key('onboarding-weight')), '61,5');
    await _next(tester);

    expect(repo.profile!.goal, TrainingGoal.hypertrophy);
    expect(repo.profile!.daysPerWeek, 4);
    expect(repo.profile!.minutesPerSession, 60);
    expect(repo.profile!.equipment, {Equipment.dumbbells, Equipment.bands});
    expect(repo.profile!.height, 1.68);
    expect(repo.profile!.toJson()['equipment'], containsAll(['DUMBBELLS', 'BANDS']));

    // triagem: todas as perguntas são obrigatórias
    expect(find.text('SUA SAÚDE'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('answer-0-no')));
    expect(_nextEnabled(tester), isFalse);
    await _answerAll(tester);
    await _next(tester);

    expect(repo.lastAnswers, List.filled(7, false));
    expect(find.text('TUDO PRONTO'), findsOneWidget);
    await _next(tester);

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
    await _close(tester);
  });

  testWidgets('resposta "sim" na triagem recomenda avaliação e avisa que não haverá treino automático', (tester) async {
    final repo = FakeOnboardingRepository(
      profile: const TrainingProfile(
        goal: TrainingGoal.health,
        level: TrainingLevel.beginner,
        daysPerWeek: 2,
        minutesPerSession: 30,
        location: TrainingLocation.bodyweight,
      ),
    );
    await _pump(tester, _app(repo));

    // perfil já salvo: vem preenchido, só falta a triagem
    expect(find.byType(OnboardingPage), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await _next(tester);
    }
    await _answerAll(tester, yesAt: 1);
    await _next(tester);

    expect(repo.lastAnswers![1], isTrue);
    expect(find.text('PROCURE UMA AVALIAÇÃO'), findsOneWidget);
    expect(find.textContaining('não vai gerar treinos automáticos'), findsOneWidget);
    await _next(tester);
    expect(find.byType(HomePage), findsOneWidget);
    await _close(tester);
  });

  testWidgets('aluno com personal não passa pelo onboarding nem vê o item no Perfil', (tester) async {
    final repo = FakeOnboardingRepository();
    await _pump(tester, _app(repo, profile: testProfile));

    expect(find.byType(HomePage), findsOneWidget);
    expect(repo.statusCalls, 0);

    await _tap(tester, find.text('Perfil'));
    expect(find.byKey(const Key('menu-training-profile')), findsNothing);
    await _close(tester);
  });

  testWidgets('aluno sem personal revisa o perfil de treino pelo Perfil', (tester) async {
    final repo = FakeOnboardingRepository(
      profile: const TrainingProfile(
        goal: TrainingGoal.strength,
        level: TrainingLevel.advanced,
        daysPerWeek: 5,
        minutesPerSession: 75,
        location: TrainingLocation.gym,
      ),
      risk: false,
    );
    await _pump(tester, _app(repo));
    expect(find.byType(HomePage), findsOneWidget);

    await _tap(tester, find.text('Perfil'));
    await _tap(tester, find.byKey(const Key('menu-training-profile')));
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(_nextEnabled(tester), isTrue); // objetivo já marcado
    await _close(tester);
  });

  test('lê o onboarding da API', () {
    final status = OnboardingStatus.fromJson({
      'trainingProfile': {
        'goal': 'WEIGHT_LOSS',
        'level': 'INTERMEDIATE',
        'daysPerWeek': 3,
        'minutesPerSession': 45,
        'location': 'HOME',
        'equipment': ['KETTLEBELL', 'DESCONHECIDO'],
        'height': 1.7,
        'weight': null,
      },
      'healthScreening': {'version': 'triagem-2026-10', 'risk': true, 'answeredAt': '2026-10-18T10:00:00'},
      'completed': true,
      'aiWorkoutsAllowed': false,
    });
    expect(status.trainingProfile!.goal, TrainingGoal.weightLoss);
    expect(status.trainingProfile!.equipment, {Equipment.kettlebell});
    expect(status.screeningRisk, isTrue);
    expect(status.aiWorkoutsAllowed, isFalse);
    expect(StudentProfile.fromJson({'id': 1, 'email': 'a@b.c', 'name': 'A', 'status': null}).hasTrainer, isFalse);
    expect(StudentProfile.fromJson({'id': 1, 'email': 'a@b.c', 'name': 'A', 'status': 'ACTIVE'}).hasTrainer, isTrue);
  });
}
