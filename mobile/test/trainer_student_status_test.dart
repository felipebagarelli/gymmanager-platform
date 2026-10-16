import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/routing/app_router.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/chat/application/chat_providers.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';
import 'package:gymmanager_mobile/features/trainer/students/application/students_providers.dart';
import 'package:gymmanager_mobile/features/trainer/students/domain/managed_student.dart';
import 'package:gymmanager_mobile/features/trainer/workouts/application/trainer_workouts_providers.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';

import 'support/fake_chat.dart';
import 'support/fake_repositories.dart';
import 'support/fake_trainer_workouts.dart';
import 'support/fakes.dart';
import 'trainer_students_test.dart' show FakeStudentsRepository;

WorkoutSession _session(int id, DateTime start, double load) => WorkoutSession(
      id: id,
      workoutId: 10,
      startedAt: start,
      finishedAt: start.add(const Duration(minutes: 50)),
      performances: [
        Performance(id: id * 10, workoutExerciseId: 100, setNumber: 1, reps: 10, loadKg: load),
        Performance(id: id * 10 + 1, workoutExerciseId: 101, setNumber: 1, reps: 12, loadKg: 60),
      ],
    );

FakeStudentsRepository _students() => FakeStudentsRepository([
      const ManagedStudent(id: 2, email: 'maria@example.com', name: 'Maria Aluna', active: true, linkStatus: LinkStatus.active),
      const ManagedStudent(id: 3, email: 'bruno@example.com', name: 'Bruno Silva', active: true, linkStatus: LinkStatus.paused),
      const ManagedStudent(id: 4, email: 'carla@example.com', name: 'Carla Souza', active: false, linkStatus: LinkStatus.active),
    ]);

Widget _app(FakeStudentsRepository students, {List<WorkoutSession> sessions = const []}) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(
          StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)), role: 'TRAINER'),
        )),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        chatRepositoryProvider.overrideWithValue(FakeTrainerChatRepository([])),
        chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
        studentsRepositoryProvider.overrideWithValue(students),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository(initial: sessions)),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        trainerWorkoutsRepositoryProvider.overrideWithValue(FakeTrainerWorkoutsRepository()),
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
  group('B2.1 evolução do aluno', () {
    testWidgets('o personal abre calendário e evolução do aluno, com os nomes dos treinos dele', (tester) async {
      final sessions = [
        _session(1, DateTime(2026, 9, 29, 7), 40),
        _session(2, DateTime(2026, 10, 6, 7), 42.5),
        _session(3, DateTime(2026, 10, 13, 7), 45),
      ];
      await _pump(tester, _app(_students(), sessions: sessions));
      await _tap(tester, find.text('Maria Aluna'));

      await _tap(tester, find.text('Calendário'));
      expect(find.text('HISTÓRICO'), findsOneWidget);
      expect(find.byKey(const Key('progress-student')), findsOneWidget);
      expect(find.byKey(const Key('session-3')), findsOneWidget);
      // nome vem dos treinos do personal (FakeTrainerWorkoutsRepository)
      expect(find.text('Treino A - Peito e tríceps'), findsWidgets);

      await _tap(tester, find.byKey(const Key('history-tab-1')));
      expect(find.byKey(const Key('progress-Agachamento')), findsOneWidget);
      await _close(tester);
    });

    testWidgets('o atalho "Evolução" já abre na aba de gráficos; sem treinos mostra o aviso', (tester) async {
      await _pump(tester, _app(_students()));
      await _tap(tester, find.text('Maria Aluna'));

      await _tap(tester, find.byKey(const Key('open-progress')));
      expect(find.textContaining('Quando o aluno finalizar treinos'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('history-tab-0')));
      expect(find.text('O aluno ainda não executou nenhum treino.'), findsOneWidget);
      await _close(tester);
    });
  });

  group('B2.2 reativar e pausar', () {
    testWidgets('lista mostra "Em pausa" e filtra', (tester) async {
      await _pump(tester, _app(_students()));

      expect(find.byKey(const Key('badge-paused')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('filter-paused')));
      expect(find.text('Bruno Silva'), findsOneWidget);
      expect(find.text('Maria Aluna'), findsNothing);

      await _tap(tester, find.byKey(const Key('filter-active')));
      expect(find.text('Maria Aluna'), findsOneWidget);
      expect(find.text('Bruno Silva'), findsNothing);
      await _close(tester);
    });

    testWidgets('pausar pede confirmação e avisa que a cobrança não é pausada; retomar volta', (tester) async {
      final repo = _students();
      await _pump(tester, _app(repo));
      await _tap(tester, find.text('Maria Aluna'));

      await _tap(tester, find.byKey(const Key('pause-student')));
      expect(find.textContaining('não é pausada'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('confirm-pause')));

      expect(repo.calls, contains('setPaused:2:true'));
      expect(find.byKey(const Key('badge-paused')), findsOneWidget);

      await _tap(tester, find.byKey(const Key('resume-student')));
      expect(repo.calls, contains('setPaused:2:false'));
      expect(find.byKey(const Key('badge-paused')), findsNothing);
      expect(find.byKey(const Key('pause-student')), findsOneWidget);
      await _close(tester);
    });

    testWidgets('aluno desativado pode ser reativado', (tester) async {
      final repo = _students();
      await _pump(tester, _app(repo));
      await _tap(tester, find.byKey(const Key('filter-inactive')));
      await _tap(tester, find.text('Carla Souza'));

      expect(find.byKey(const Key('badge-inactive')), findsOneWidget);
      expect(find.byKey(const Key('deactivate-student')), findsNothing);
      await _tap(tester, find.byKey(const Key('reactivate-student')));

      expect(repo.calls, contains('reactivate:4'));
      expect(find.byKey(const Key('badge-inactive')), findsNothing);
      expect(find.byKey(const Key('deactivate-student')), findsOneWidget);
      await _close(tester);
    });
  });
}
