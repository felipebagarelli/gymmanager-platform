import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/features/workouts/data/workout_repository.dart';
import 'package:gymmanager_mobile/features/workouts/domain/workout.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/routing/app_router.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';
import 'package:gymmanager_mobile/features/trainer/students/application/students_providers.dart';
import 'package:gymmanager_mobile/features/trainer/students/data/students_repository.dart';
import 'package:gymmanager_mobile/features/trainer/students/domain/managed_student.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';

import 'support/fake_repositories.dart';
import 'support/fakes.dart';

final _now = DateTime(2026, 10, 15, 12); // quinta

/// Alunos em memória, como o servidor guardaria.
class FakeStudentsRepository extends StudentsRepository {
  FakeStudentsRepository(this.students, {this.tuitionMap = const {}}) : super(Dio());

  final List<ManagedStudent> students;
  final Map<int, TuitionStatus> tuitionMap;
  final calls = <String>[];
  AppException? createError;
  StudentDraft? lastDraft;
  int _nextId = 100;

  @override
  Future<List<ManagedStudent>> list(int trainerId) async {
    calls.add('list:$trainerId');
    return [...students];
  }

  @override
  Future<ManagedStudent> get(int studentId) async => students.firstWhere((s) => s.id == studentId);

  ManagedStudent _from(int id, String email, StudentDraft d, {bool active = true}) => ManagedStudent(
        id: id,
        email: email,
        name: d.name,
        active: active,
        birthDate: d.birthDate,
        phone: d.phone,
        goal: d.goal,
        height: d.height,
        weight: d.weight,
        weeklyGoal: d.weeklyGoal,
        linkStatus: LinkStatus.active,
      );

  @override
  Future<ManagedStudent> create(int trainerId, StudentDraft draft, {required String email, required String password}) async {
    if (createError != null) throw createError!;
    calls.add('create:$trainerId:$email:${password.length}');
    lastDraft = draft;
    final created = _from(_nextId++, email, draft);
    students.add(created);
    return created;
  }

  @override
  Future<ManagedStudent> update(int studentId, StudentDraft draft) async {
    calls.add('update:$studentId');
    lastDraft = draft;
    final i = students.indexWhere((s) => s.id == studentId);
    students[i] = _from(studentId, students[i].email, draft, active: students[i].active);
    return students[i];
  }

  @override
  Future<void> deactivate(int studentId) async {
    calls.add('deactivate:$studentId');
    final i = students.indexWhere((s) => s.id == studentId);
    final s = students[i];
    students[i] = ManagedStudent(id: s.id, email: s.email, name: s.name, active: false, weeklyGoal: s.weeklyGoal, lastWorkoutAt: s.lastWorkoutAt);
  }

  @override
  Future<Map<int, TuitionStatus>> tuition() async => tuitionMap;

  ManagedStudent _copy(ManagedStudent s, {bool? active, LinkStatus? link}) => ManagedStudent(
        id: s.id,
        email: s.email,
        name: s.name,
        active: active ?? s.active,
        phone: s.phone,
        goal: s.goal,
        height: s.height,
        weight: s.weight,
        weeklyGoal: s.weeklyGoal,
        lastWorkoutAt: s.lastWorkoutAt,
        linkStatus: link ?? s.linkStatus,
      );

  @override
  Future<ManagedStudent> reactivate(int studentId) async {
    calls.add('reactivate:$studentId');
    final i = students.indexWhere((s) => s.id == studentId);
    return students[i] = _copy(students[i], active: true);
  }

  @override
  Future<ManagedStudent> setPaused(int studentId, bool paused) async {
    calls.add('setPaused:$studentId:$paused');
    final i = students.indexWhere((s) => s.id == studentId);
    return students[i] = _copy(students[i], link: paused ? LinkStatus.paused : LinkStatus.active);
  }
}

List<ManagedStudent> _students() => [
      ManagedStudent(
        id: 2,
        email: 'maria@example.com',
        name: 'Maria Aluna',
        active: true,
        phone: '11 98888-0000',
        goal: 'Hipertrofia',
        height: 1.65,
        weight: 60,
        weeklyGoal: 3,
        lastWorkoutAt: DateTime(2026, 10, 14, 7),
      ),
      const ManagedStudent(id: 3, email: 'bruno@example.com', name: 'Bruno Silva', active: true),
      ManagedStudent(id: 4, email: 'carla@example.com', name: 'Carla Souza', active: false, lastWorkoutAt: DateTime(2026, 8, 1)),
    ];

WorkoutSession _session(int id, DateTime start, List<Performance> sets) =>
    WorkoutSession(id: id, workoutId: 10, startedAt: start, finishedAt: start.add(const Duration(minutes: 45)), performances: sets);

/// Lembra os dias salvos e devolve os treinos com eles.
class _ScheduleWorkouts extends FakeWorkoutRepository {
  final Map<int, Set<int>> days = {};
  final saved = <Map<int, Set<int>>>[];

  @override
  Future<List<Workout>> myWorkouts(int studentId) async => [
        for (final w in await super.myWorkouts(studentId))
          Workout(id: w.id, name: w.name, weekdays: (days[w.id] ?? const <int>{}).toList()..sort()),
      ];

  @override
  Future<List<Workout>> setSchedule(int studentId, Map<int, Set<int>> days) async {
    saved.add(days);
    this.days.addAll(days);
    return myWorkouts(studentId);
  }
}

Widget _app(FakeStudentsRepository students, {List<WorkoutSession> sessions = const [], WorkoutRepository? workouts}) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(
          StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)), role: 'TRAINER'),
        )),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        studentsRepositoryProvider.overrideWithValue(students),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository(initial: sessions)),
        workoutRepositoryProvider.overrideWithValue(workouts ?? FakeWorkoutRepository()),
        clockProvider.overrideWithValue(() => _now),
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

Finder _in(String key, Finder matching) => find.descendant(of: find.byKey(Key(key)), matching: matching);

void main() {
  group('lista de alunos', () {
    testWidgets('mostra os alunos em ordem alfabética, último treino e situação', (tester) async {
      final repo = FakeStudentsRepository(_students(), tuitionMap: {2: TuitionStatus.overdue});
      await _pump(tester, _app(repo));

      expect(repo.calls, contains('list:5'));
      expect(find.text('2 alunos ativos'), findsOneWidget);
      final names = tester.widgetList<Text>(find.textContaining(RegExp(r'^(Bruno|Carla|Maria) '))).map((t) => t.data).toList();
      expect(names, ['Bruno Silva', 'Carla Souza', 'Maria Aluna']);
      expect(_in('student-2', find.text('Último treino: ontem')), findsOneWidget);
      expect(_in('student-3', find.text('Ainda não treinou')), findsOneWidget);
      expect(_in('student-4', find.text('Último treino: 01/08/2026')), findsOneWidget);
      expect(_in('student-2', find.byKey(const Key('badge-overdue'))), findsOneWidget);
      expect(_in('student-4', find.byKey(const Key('badge-inactive'))), findsOneWidget);
    });

    testWidgets('busca por nome ou e-mail e filtros por situação', (tester) async {
      final repo = FakeStudentsRepository(_students(), tuitionMap: {2: TuitionStatus.overdue});
      await _pump(tester, _app(repo));

      await tester.enterText(find.byKey(const Key('students-search')), 'bruno@');
      await tester.pump();
      expect(find.byKey(const Key('student-3')), findsOneWidget);
      expect(find.byKey(const Key('student-2')), findsNothing);

      await tester.enterText(find.byKey(const Key('students-search')), '');
      await tester.tap(find.byKey(const Key('filter-overdue')));
      await tester.pump();
      expect(find.byKey(const Key('student-2')), findsOneWidget);
      expect(find.byKey(const Key('student-3')), findsNothing);

      await tester.tap(find.byKey(const Key('filter-inactive')));
      await tester.pump();
      expect(find.byKey(const Key('student-4')), findsOneWidget);
      expect(find.byKey(const Key('student-2')), findsNothing);

      await tester.enterText(find.byKey(const Key('students-search')), 'ninguém');
      await tester.pump();
      expect(find.byKey(const Key('students-none')), findsOneWidget);
    });

    testWidgets('sem alunos, convida a cadastrar o primeiro', (tester) async {
      await _pump(tester, _app(FakeStudentsRepository([])));

      expect(find.textContaining('Você ainda não tem alunos'), findsOneWidget);
    });
  });

  group('perfil do aluno', () {
    testWidgets('dados, números da semana, treinos e sessões com o "Como foi?"', (tester) async {
      final repo = FakeStudentsRepository(_students());
      await _pump(
        tester,
        _app(repo, sessions: [
          _session(1, DateTime(2026, 10, 13, 7), const [
            Performance(id: 1, workoutExerciseId: 100, setNumber: 1, reps: 10, loadKg: 40, effort: Effort.hard),
          ]),
          _session(2, DateTime(2026, 10, 14, 7), const [
            Performance(id: 2, workoutExerciseId: 100, setNumber: 1, reps: 12, loadKg: 40),
          ]),
        ]),
      );

      await tester.tap(find.byKey(const Key('student-2')));
      await tester.pumpAndSettle();

      expect(find.text('MARIA ALUNA'), findsOneWidget);
      expect(_in('student-info', find.text('11 98888-0000')), findsOneWidget);
      expect(_in('student-info', find.text('Hipertrofia')), findsOneWidget);
      expect(_in('student-info', find.text('1,65 m')), findsOneWidget);
      expect(_in('student-info', find.text('3 treinos')), findsOneWidget);
      expect(_in('stat-done', find.text('2')), findsOneWidget);
      expect(_in('stat-week', find.text('2/3')), findsOneWidget);
      expect(find.text('Treino A'), findsWidgets);
      expect(find.byKey(const Key('session-2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('session-1')));
      await tester.pumpAndSettle();
      expect(_in('session-detail', find.text('Difícil')), findsOneWidget);
    });

    testWidgets('organizar a semana define os dias de cada treino do aluno', (tester) async {
      final workouts = _ScheduleWorkouts();
      await _pump(tester, _app(FakeStudentsRepository(_students()), workouts: workouts));
      await tester.tap(find.byKey(const Key('student-2')));
      await tester.pumpAndSettle();

      expect(_in('student-workout-10', find.text('Sem dia definido')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('edit-week')));
      await tester.tap(find.byKey(const Key('edit-week')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('day-1-workout-10')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('day-4-workout-11')));
      await tester.tap(find.byKey(const Key('day-4-workout-11')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-week')));
      await tester.pumpAndSettle();

      expect(workouts.saved.single, {10: {1}, 11: {4}});
      expect(_in('student-workout-10', find.text('Seg')), findsOneWidget);
      expect(_in('student-workout-11', find.text('Qui')), findsOneWidget);
    });

    testWidgets('sem treinos e sem sessões, explica em vez de mostrar vazio', (tester) async {
      await _pump(tester, _app(FakeStudentsRepository(_students())));

      await tester.tap(find.byKey(const Key('student-3')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('no-sessions')), findsOneWidget);
      expect(_in('stat-week', find.text('0')), findsOneWidget);
      expect(_in('student-info', find.text('Sem meta')), findsOneWidget);
    });

    testWidgets('desativar pede confirmação e marca o aluno como inativo', (tester) async {
      final repo = FakeStudentsRepository(_students());
      await _pump(tester, _app(repo));
      await tester.tap(find.byKey(const Key('student-3')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('deactivate-student')));
      await tester.pumpAndSettle();
      expect(find.text('Desativar aluno?'), findsOneWidget);
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      expect(repo.calls, isNot(contains('deactivate:3')));

      await tester.tap(find.byKey(const Key('deactivate-student')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-deactivate')));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('deactivate:3'));
      expect(find.byKey(const Key('badge-inactive')), findsOneWidget);
      expect(find.byKey(const Key('deactivate-student')), findsNothing);
    });
  });

  group('cadastro e edição', () {
    testWidgets('editar vem preenchido; muda a meta semanal e salva', (tester) async {
      final repo = FakeStudentsRepository(_students());
      await _pump(tester, _app(repo));
      await tester.tap(find.byKey(const Key('student-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-student')));
      await tester.pumpAndSettle();

      expect(find.text('EDITAR ALUNO'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Maria Aluna'), findsOneWidget);
      expect(find.widgetWithText(TextField, '1,65'), findsOneWidget);
      expect(find.byKey(const Key('field-email')), findsNothing); // e-mail e senha só no cadastro
      expect(find.text('3 treinos por semana'), findsOneWidget);

      await tester.tap(find.byKey(const Key('weekly-goal-plus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-student')));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('update:2'));
      expect(repo.lastDraft!.weeklyGoal, 4);
      expect(repo.lastDraft!.height, 1.65);
      expect(find.text('Dados salvos'), findsOneWidget);
      expect(_in('student-info', find.text('4 treinos')), findsOneWidget); // voltou ao perfil já atualizado
    });

    testWidgets('meta em zero vira "sem meta"', (tester) async {
      final repo = FakeStudentsRepository(_students());
      await _pump(tester, _app(repo));
      await tester.tap(find.byKey(const Key('student-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-student')));
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('weekly-goal-minus')));
        await tester.pump();
      }
      expect(find.text('Sem meta'), findsOneWidget);
      await tester.tap(find.byKey(const Key('save-student')));
      await tester.pumpAndSettle();

      expect(repo.lastDraft!.weeklyGoal, isNull);
    });

    testWidgets('cadastro valida os campos antes de chamar a API', (tester) async {
      final repo = FakeStudentsRepository(_students());
      await _pump(tester, _app(repo));
      await tester.tap(find.byKey(const Key('new-student')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('field-email')), 'sem-arroba');
      await tester.enterText(find.byKey(const Key('field-password')), '123');
      await tester.enterText(find.byKey(const Key('field-birth')), '31/02/1990');
      await tester.enterText(find.byKey(const Key('field-height')), '170');
      await tester.tap(find.byKey(const Key('save-student')));
      await tester.pump();

      expect(find.text('Informe o nome'), findsOneWidget);
      expect(find.text('E-mail inválido'), findsOneWidget);
      expect(find.text('Mínimo de 8 caracteres'), findsOneWidget);
      expect(find.text('Use dd/mm/aaaa'), findsOneWidget);
      expect(find.text('Altura em metros (ex.: 1,70)'), findsOneWidget);
      expect(repo.calls.where((c) => c.startsWith('create')), isEmpty);
    });

    testWidgets('cadastro válido cria o aluno e ele aparece na lista', (tester) async {
      final repo = FakeStudentsRepository(_students());
      await _pump(tester, _app(repo));
      await tester.tap(find.byKey(const Key('new-student')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('field-name')), 'Diego Lima');
      await tester.enterText(find.byKey(const Key('field-email')), 'diego@example.com');
      await tester.enterText(find.byKey(const Key('field-password')), 'provisoria1');
      await tester.enterText(find.byKey(const Key('field-birth')), '05/10/1990');
      await tester.tap(find.byKey(const Key('weekly-goal-plus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-student')));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('create:5:diego@example.com:11'));
      expect(repo.lastDraft!.birthDate, DateTime(1990, 10, 5));
      expect(repo.lastDraft!.weeklyGoal, 1);
      expect(find.text('Aluno cadastrado'), findsOneWidget);
      expect(find.byKey(const Key('student-100')), findsOneWidget);
      expect(find.text('3 alunos ativos'), findsOneWidget);
    });

    testWidgets('erro do servidor (e-mail já usado) aparece e o formulário continua aberto', (tester) async {
      final repo = FakeStudentsRepository(_students())..createError = AppException('E-mail já está em uso!', statusCode: 409);
      await _pump(tester, _app(repo));
      await tester.tap(find.byKey(const Key('new-student')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('field-name')), 'Diego');
      await tester.enterText(find.byKey(const Key('field-email')), 'maria@example.com');
      await tester.enterText(find.byKey(const Key('field-password')), 'provisoria1');
      await tester.tap(find.byKey(const Key('save-student')));
      await tester.pumpAndSettle();

      expect(find.text('E-mail já está em uso!'), findsOneWidget);
      expect(find.text('NOVO ALUNO'), findsOneWidget);
    });
  });
}
