import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/routing/app_router.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/chat/application/chat_providers.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/trainer/students/application/students_providers.dart';
import 'package:gymmanager_mobile/features/trainer/students/domain/managed_student.dart';
import 'package:gymmanager_mobile/features/trainer/workouts/application/trainer_workouts_providers.dart';
import 'package:gymmanager_mobile/features/trainer/workouts/domain/workout_draft.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';

import 'support/fake_chat.dart';
import 'support/fake_repositories.dart';
import 'support/fake_trainer_workouts.dart';
import 'support/fakes.dart';
import 'trainer_students_test.dart' show FakeStudentsRepository;

StoredSession _trainerSession() =>
    StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)), role: 'TRAINER');

FakeStudentsRepository _students() => FakeStudentsRepository([
      const ManagedStudent(id: 2, email: 'maria@example.com', name: 'Maria Aluna', active: true),
      const ManagedStudent(id: 3, email: 'bruno@example.com', name: 'Bruno Silva', active: true),
      const ManagedStudent(id: 4, email: 'carla@example.com', name: 'Carla Souza', active: false),
    ]);

FakeTrainerWorkoutsRepository _workouts() => FakeTrainerWorkoutsRepository(workouts: {
      10: 'Treino A - Peito e tríceps',
      11: 'Treino B - Pernas',
      12: 'Treino C - Costas',
    });

Widget _app(FakeTrainerWorkoutsRepository workouts) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(_trainerSession())),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        chatRepositoryProvider.overrideWithValue(FakeTrainerChatRepository([])),
        chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
        trainerWorkoutsRepositoryProvider.overrideWithValue(workouts),
        studentsRepositoryProvider.overrideWithValue(_students()),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 15, 12)),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(theme: AppTheme.dark(), routerConfig: ref.watch(routerProvider)),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openWorkouts(WidgetTester tester) => _tap(tester, find.text('Treinos'));

Future<void> _openEditor(WidgetTester tester, int workoutId) async {
  await _openWorkouts(tester);
  await _tap(tester, find.byKey(Key('workout-$workoutId')));
}

Finder _in(String key, Finder matching) => find.descendant(of: find.byKey(Key(key)), matching: matching);

void main() {
  group('aba Treinos', () {
    testWidgets('lista os treinos com exercícios e alunos, e abre o editor', (tester) async {
      final repo = _workouts()
        ..seedPlan(10, const [PlanItemDraft(exerciseId: 1), PlanItemDraft(exerciseId: 3)])
        ..assigned[10]![2] = 'Maria Aluna';
      await _pump(tester, _app(repo));
      await _openWorkouts(tester);

      expect(find.text('3 treinos montados'), findsOneWidget);
      expect(_in('workout-10', find.text('Peito e tríceps')), findsOneWidget);
      expect(_in('workout-10', find.text('2 exercícios · 1 aluno')), findsOneWidget);
      expect(_in('workout-11', find.text('Sem exercícios · Nenhum aluno')), findsOneWidget);

      await _tap(tester, find.byKey(const Key('workout-10')));
      expect(find.text('PEITO E TRÍCEPS'), findsOneWidget);
      expect(find.text('Supino reto'), findsOneWidget);
      expect(find.text('Tríceps corda'), findsOneWidget);
      expect(find.byKey(const Key('assignee-2')), findsOneWidget);
      await _close(tester);
    });

    testWidgets('novo treino: dá o nome e já abre o editor vazio', (tester) async {
      final repo = _workouts();
      await _pump(tester, _app(repo));
      await _openWorkouts(tester);

      await _tap(tester, find.byKey(const Key('new-workout')));
      await tester.enterText(find.byKey(const Key('workout-name')), 'Treino D - Ombros');
      await _tap(tester, find.byKey(const Key('workout-name-save')));

      expect(repo.calls, contains('create:Treino D - Ombros'));
      expect(find.text('OMBROS'), findsOneWidget);
      expect(find.text('Nenhum exercício ainda'), findsOneWidget);
      expect(find.byKey(const Key('no-assignees')), findsOneWidget);
      await _close(tester);
    });

    testWidgets('nome em branco não cria o treino', (tester) async {
      final repo = _workouts();
      await _pump(tester, _app(repo));
      await _openWorkouts(tester);

      await _tap(tester, find.byKey(const Key('new-workout')));
      await _tap(tester, find.byKey(const Key('workout-name-save')));

      expect(find.text('Dê um nome ao treino'), findsOneWidget);
      expect(repo.calls.where((c) => c.startsWith('create')), isEmpty);
      await _close(tester);
    });
  });

  group('editor do treino', () {
    testWidgets('adiciona um exercício da biblioteca com séries e repetições', (tester) async {
      final repo = _workouts();
      await _pump(tester, _app(repo));
      await _openEditor(tester, 11);

      await _tap(tester, find.byKey(const Key('add-exercise')));
      expect(find.text('ESCOLHER EXERCÍCIO'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('picker-search')), 'agach');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exercise-1')), findsNothing);
      await _tap(tester, find.byKey(const Key('exercise-2')));

      // sheet já vem com 3 × 12 e 60 s; o personal ajusta para 4 séries
      await _tap(tester, find.byTooltip('mais séries'));
      await _tap(tester, find.byKey(const Key('item-save')));

      expect(repo.calls, contains('addItem:11:2:4x12'));
      expect(_in('plan-item-${repo.plans[11]!.single.id}', find.text('Agachamento livre')), findsOneWidget);
      expect(find.text('4 × 12 · 60 s'), findsOneWidget);
      expect(find.byKey(const Key('workout-summary')), findsOneWidget);
      expect(find.textContaining('1 exercício · 4 séries'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('cria um exercício novo no meio da montagem', (tester) async {
      final repo = _workouts();
      await _pump(tester, _app(repo));
      await _openEditor(tester, 11);

      await _tap(tester, find.byKey(const Key('add-exercise')));
      await _tap(tester, find.byKey(const Key('picker-new-exercise')));
      await tester.enterText(find.byKey(const Key('exercise-name')), 'Afundo no smith');
      await _tap(tester, find.byKey(const Key('group-Pernas')));
      await _tap(tester, find.byKey(const Key('exercise-save')));

      // volta direto para os valores do exercício recém-criado
      expect(find.text('AFUNDO NO SMITH'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('item-save')));

      expect(repo.calls, contains('createExercise:Afundo no smith:Pernas'));
      expect(find.text('Afundo no smith'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('ajusta e retira um exercício do plano', (tester) async {
      final repo = _workouts()..seedPlan(10, const [PlanItemDraft(exerciseId: 1), PlanItemDraft(exerciseId: 3)]);
      final first = repo.plans[10]!.first.id;
      await _pump(tester, _app(repo));
      await _openEditor(tester, 10);

      await _tap(tester, find.byKey(Key('plan-item-$first')));
      await tester.enterText(find.byKey(const Key('item-load')), '22,5');
      await tester.enterText(find.byKey(const Key('item-notes')), 'Descer devagar');
      await _tap(tester, find.byKey(const Key('item-save')));

      expect(repo.calls, contains('updateItem:$first:3x12:22.5:Descer devagar'));
      expect(find.text('3 × 12 · 60 s · 22,5 kg'), findsOneWidget);
      expect(find.text('Descer devagar'), findsOneWidget);

      await _tap(tester, find.byKey(Key('plan-item-$first')));
      await _tap(tester, find.byKey(const Key('item-remove')));

      expect(repo.calls, contains('removeItem:$first'));
      expect(find.byKey(Key('plan-item-$first')), findsNothing);
      expect(find.text('Supino reto'), findsNothing);
      await _close(tester);
    });

    testWidgets('atribui a alunos ativos e retira de um aluno', (tester) async {
      final repo = _workouts();
      await _pump(tester, _app(repo));
      await _openEditor(tester, 10);

      await _tap(tester, find.text('Atribuir'));
      expect(find.byKey(const Key('assign-student-2')), findsOneWidget);
      expect(find.byKey(const Key('assign-student-4')), findsNothing); // inativa
      await _tap(tester, find.byKey(const Key('assign-student-2')));
      await _tap(tester, find.byKey(const Key('assign-student-3')));
      expect(_in('assign-confirm', find.text('ATRIBUIR A 2 ALUNOS')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('assign-confirm')));

      expect(repo.calls, containsAll(['assign:10:2', 'assign:10:3']));
      expect(find.byKey(const Key('assignee-2')), findsOneWidget);
      expect(find.byKey(const Key('assignee-3')), findsOneWidget);

      await _tap(tester, find.byKey(const Key('unassign-3')));
      await _tap(tester, find.byKey(const Key('confirm-unassign')));

      expect(repo.calls, contains('unassign:10:3'));
      expect(find.byKey(const Key('assignee-3')), findsNothing);
      await _close(tester);
    });

    testWidgets('duplicar abre a cópia com o mesmo plano', (tester) async {
      final repo = _workouts()..seedPlan(10, const [PlanItemDraft(exerciseId: 1)]);
      await _pump(tester, _app(repo));
      await _openEditor(tester, 10);

      await _tap(tester, find.byKey(const Key('workout-menu')));
      await _tap(tester, find.byKey(const Key('workout-duplicate')));

      expect(repo.calls, contains('duplicate:10'));
      expect(find.text('PEITO E TRÍCEPS (CÓPIA)'), findsOneWidget);
      expect(find.text('Supino reto'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('treino montado pelo aluno: o personal ajusta, sem atribuir, duplicar ou excluir', (tester) async {
      final repo = _workouts()..seedStudentWorkout(77, 'Treino da Maria');
      await _pump(tester, _app(repo));
      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      container.read(routerProvider).push('/trainer/workouts/77');
      await tester.pumpAndSettle();

      expect(find.text('TREINO DA MARIA'), findsOneWidget);
      expect(find.byKey(const Key('student-owned-note')), findsOneWidget);
      expect(find.byKey(const Key('no-assignees')), findsNothing);
      await _tap(tester, find.byKey(const Key('workout-menu')));
      expect(find.byKey(const Key('workout-rename')), findsOneWidget);
      expect(find.byKey(const Key('workout-duplicate')), findsNothing);
      expect(find.byKey(const Key('workout-delete')), findsNothing);
      await _close(tester);
    });

    testWidgets('renomear atualiza o título', (tester) async {
      final repo = _workouts();
      await _pump(tester, _app(repo));
      await _openEditor(tester, 11);

      await _tap(tester, find.byKey(const Key('workout-menu')));
      await _tap(tester, find.byKey(const Key('workout-rename')));
      await tester.enterText(find.byKey(const Key('workout-name')), 'Treino B - Pernas e glúteos');
      await _tap(tester, find.byKey(const Key('workout-name-save')));

      expect(find.text('PERNAS E GLÚTEOS'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('excluir: treino já atribuído mostra o motivo; sem atribuição, volta para a lista', (tester) async {
      final repo = _workouts()..everAssigned.add(10);
      await _pump(tester, _app(repo));
      await _openEditor(tester, 10);

      await _tap(tester, find.byKey(const Key('workout-menu')));
      await _tap(tester, find.byKey(const Key('workout-delete')));
      await _tap(tester, find.byKey(const Key('confirm-delete-workout')));
      expect(find.textContaining('já foi atribuído'), findsOneWidget);
      expect(find.text('PEITO E TRÍCEPS'), findsOneWidget);

      await _tap(tester, find.byTooltip('Voltar'));
      await _tap(tester, find.byKey(const Key('workout-11')));
      await _tap(tester, find.byKey(const Key('workout-menu')));
      await _tap(tester, find.byKey(const Key('workout-delete')));
      await _tap(tester, find.byKey(const Key('confirm-delete-workout')));

      expect(repo.calls, contains('delete:11'));
      expect(find.byKey(const Key('workout-11')), findsNothing);
      expect(find.text('2 treinos montados'), findsOneWidget);
      await _close(tester);
    });
  });

  group('reordenar', () {
    Future<(ProviderContainer, FakeTrainerWorkoutsRepository)> setup() async {
      final repo = _workouts()
        ..seedPlan(10, const [PlanItemDraft(exerciseId: 1), PlanItemDraft(exerciseId: 2), PlanItemDraft(exerciseId: 3)]);
      final c = ProviderContainer(retry: (retryCount, error) => null, overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(_trainerSession())),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        trainerWorkoutsRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(workoutPlanEditorProvider(10), (_, _) {});
      addTearDown(sub.close);
      await c.read(workoutPlanEditorProvider(10).future);
      return (c, repo);
    }

    List<String?> names(ProviderContainer c) => [for (final i in c.read(workoutPlanEditorProvider(10)).value!) i.exerciseName];

    test('move o exercício e grava a ordem inteira no servidor', () async {
      final (c, repo) = await setup();
      final ids = [for (final i in repo.plans[10]!) i.id];

      await c.read(workoutPlanEditorProvider(10).notifier).move(0, 2);

      expect(names(c), ['Agachamento livre', 'Tríceps corda', 'Supino reto']);
      expect(repo.calls.last, 'reorder:10:${ids[1]},${ids[2]},${ids[0]}');
    });

    test('se o servidor recusar, volta à ordem anterior', () async {
      final (c, repo) = await setup();
      repo.reorderError = AppException('Falhou');

      await expectLater(c.read(workoutPlanEditorProvider(10).notifier).move(2, 0), throwsA(isA<AppException>()));

      expect(names(c), ['Supino reto', 'Agachamento livre', 'Tríceps corda']);
    });

    test('soltar no mesmo lugar não chama o servidor', () async {
      final (c, repo) = await setup();

      await c.read(workoutPlanEditorProvider(10).notifier).move(1, 1);

      expect(repo.calls.where((x) => x.startsWith('reorder')), isEmpty);
    });
  });

  group('biblioteca de exercícios', () {
    testWidgets('catálogo é só leitura; os do personal podem ser editados e criados', (tester) async {
      final repo = _workouts();
      await _pump(tester, _app(repo));
      await _openWorkouts(tester);
      await _tap(tester, find.byKey(const Key('open-library')));

      expect(find.text('3 na biblioteca · 1 criado por você'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('exercise-1')));
      expect(find.textContaining('catálogo'), findsOneWidget);
      expect(find.text('EDITAR EXERCÍCIO'), findsNothing);

      await _tap(tester, find.byKey(const Key('exercise-3')));
      await tester.enterText(find.byKey(const Key('exercise-name')), 'Tríceps na corda');
      await _tap(tester, find.byKey(const Key('exercise-save')));
      expect(repo.calls, contains('updateExercise:3:Tríceps na corda:Tríceps'));
      expect(find.text('Tríceps na corda'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('new-exercise')));
      await tester.enterText(find.byKey(const Key('exercise-name')), 'Face pull');
      await _tap(tester, find.byKey(const Key('exercise-save')));
      expect(find.text('Escolha ou digite o grupo muscular'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('group-Ombros')));
      await _tap(tester, find.byKey(const Key('exercise-save')));

      expect(repo.calls, contains('createExercise:Face pull:Ombros'));
      expect(find.text('4 na biblioteca · 2 criados por você'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('library-only-mine')));
      expect(find.byKey(const Key('exercise-1')), findsNothing);
      expect(find.text('Face pull'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('excluir um exercício do personal pede confirmação', (tester) async {
      final repo = _workouts();
      await _pump(tester, _app(repo));
      await _openWorkouts(tester);
      await _tap(tester, find.byKey(const Key('open-library')));

      await _tap(tester, find.byKey(const Key('exercise-3')));
      await _tap(tester, find.byKey(const Key('exercise-delete')));
      await _tap(tester, find.byKey(const Key('confirm-delete-exercise')));

      expect(repo.calls, contains('deleteExercise:3'));
      expect(find.byKey(const Key('exercise-3')), findsNothing);
      await _close(tester);
    });
  });

  testWidgets('no perfil do aluno, "Atribuir" oferece só os treinos que ele ainda não tem', (tester) async {
    final repo = _workouts();
    await _pump(tester, _app(repo));
    await _tap(tester, find.text('Maria Aluna'));

    // o aluno já tem os treinos 10 e 11 (FakeWorkoutRepository); tocar abre o editor
    expect(find.byKey(const Key('student-workout-10')), findsOneWidget);
    await _tap(tester, find.text('Atribuir'));
    expect(find.byKey(const Key('assign-workout-10')), findsNothing);
    await _tap(tester, find.byKey(const Key('assign-workout-12')));

    expect(repo.calls, contains('assign:12:2'));
    expect(find.text('ATRIBUIR TREINO'), findsNothing);

    await _tap(tester, find.byKey(const Key('student-workout-10')));
    expect(find.text('PEITO E TRÍCEPS'), findsOneWidget);
    await _close(tester);
  });
}
