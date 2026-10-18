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
import 'package:gymmanager_mobile/features/chat/domain/chat.dart';
import 'package:gymmanager_mobile/features/hub/application/hub_providers.dart';
import 'package:gymmanager_mobile/features/onboarding/application/onboarding_providers.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/trainer/workouts/application/trainer_workouts_providers.dart';
import 'package:gymmanager_mobile/features/trainer/workouts/presentation/workout_editor_page.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';
import 'package:gymmanager_mobile/features/workouts/data/workout_repository.dart';
import 'package:gymmanager_mobile/features/workouts/domain/workout.dart';

import 'onboarding_test.dart' show FakeOnboardingRepository;
import 'support/fake_chat.dart';
import 'support/fake_hub.dart';
import 'support/fake_repositories.dart';
import 'support/fake_trainer_workouts.dart';
import 'support/fakes.dart';

/// Treinos do aluno: a lista que o servidor devolve para ele (os que estão ativos).
class _StudentWorkouts extends WorkoutRepository {
  _StudentWorkouts(this.items) : super(Dio());

  final List<Workout> items;

  @override
  Future<List<Workout>> myWorkouts(int studentId) async => [...items];

  @override
  Future<List<PlanItem>> plan(int workoutId) async => const [];

  @override
  Future<List<Exercise>> exercises() async => const [];
}

class _NoConversation extends FakeChatRepository {
  @override
  Future<List<ConversationSummary>> conversations() async => const [];
}

const _independent = StudentProfile(id: 9, email: 'ana@example.com', name: 'Ana Independente', hasTrainer: false);

Widget _app({
  StudentProfile profile = _independent,
  List<Workout> workouts = const [],
  FakeTrainerWorkoutsRepository? builder,
}) =>
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(
          StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)), role: 'STUDENT'),
        )),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(profile: profile)),
        onboardingRepositoryProvider.overrideWithValue(FakeOnboardingRepository()),
        chatRepositoryProvider.overrideWithValue(_NoConversation()),
        chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
        workoutRepositoryProvider.overrideWithValue(_StudentWorkouts(workouts)),
        trainerWorkoutsRepositoryProvider.overrideWithValue(builder ?? FakeTrainerWorkoutsRepository(workouts: {})),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 18, 12)),
        // o onboarding já foi feito nesses testes
        needsOnboardingProvider.overrideWithValue(false),
        hubRepositoryProvider.overrideWithValue(FakeHubRepository()),
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
  testWidgets('sem treinos: convida a montar o primeiro e abre o editor do aluno', (tester) async {
    final builder = FakeTrainerWorkoutsRepository(workouts: {});
    await _pump(tester, _app(builder: builder));

    expect(find.text('MONTE SEU PRIMEIRO TREINO'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('build-first-workout')));
    await tester.enterText(find.byKey(const Key('workout-name')), 'Treino A - Superiores');
    await _tap(tester, find.byKey(const Key('workout-name-save')));

    expect(builder.calls, contains('create:Treino A - Superiores'));
    final editor = tester.widget<WorkoutEditorPage>(find.byType(WorkoutEditorPage));
    expect(editor.studentMode, isTrue);
    expect(find.text('SUPERIORES'), findsOneWidget);
    // sem atribuir a alunos
    expect(find.text('ALUNOS COM ESTE TREINO'), findsNothing);

    // só o catálogo: sem criar exercício
    await _tap(tester, find.byKey(const Key('add-exercise')));
    expect(find.text('ESCOLHER EXERCÍCIO'), findsOneWidget);
    expect(find.byKey(const Key('picker-new-exercise')), findsNothing);
    await _close(tester);
  });

  testWidgets('com treinos: botão para montar outro e editar o próprio treino', (tester) async {
    final builder = FakeTrainerWorkoutsRepository(workouts: {10: 'Treino A - Superiores'});
    await _pump(tester, _app(workouts: const [Workout(id: 10, name: 'Treino A - Superiores')], builder: builder));

    expect(find.byKey(const Key('new-own-workout')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('hero-start')));
    await _tap(tester, find.byKey(const Key('edit-own-workout')));

    expect(find.byType(WorkoutEditorPage), findsOneWidget);
    await _close(tester);
  });

  testWidgets('aluno com personal não monta treino nem edita os do personal', (tester) async {
    await _pump(tester, _app(
      profile: testProfile,
      workouts: const [Workout(id: 10, name: 'Treino A - Superiores', trainerId: 5)],
    ));

    expect(find.byKey(const Key('new-own-workout')), findsNothing);
    await _tap(tester, find.byKey(const Key('hero-start')));
    expect(find.byKey(const Key('edit-own-workout')), findsNothing);
    await _close(tester);
  });

  testWidgets('Mensagens do aluno sem personal apresenta a busca de personais', (tester) async {
    await _pump(tester, _app());
    await _tap(tester, find.text('Mensagens'));

    expect(find.byKey(const Key('find-trainer')), findsOneWidget);
    expect(find.text('ENCONTRE UM PERSONAL'), findsOneWidget);
    await _close(tester);
  });

  test('treino sem personal é do aluno', () {
    expect(Workout.fromJson({'id': 1, 'name': 'A', 'trainerId': null}).ownedByStudent, isTrue);
    expect(Workout.fromJson({'id': 1, 'name': 'A', 'trainerId': 5}).ownedByStudent, isFalse);
  });
}
