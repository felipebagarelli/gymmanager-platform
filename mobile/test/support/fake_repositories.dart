import 'package:dio/dio.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/features/sessions/data/session_repository.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';
import 'package:gymmanager_mobile/features/workouts/data/workout_repository.dart';
import 'package:gymmanager_mobile/features/workouts/domain/workout.dart';

class FakeWorkoutRepository extends WorkoutRepository {
  FakeWorkoutRepository() : super(Dio());

  @override
  Future<List<Workout>> myWorkouts(int studentId) async =>
      const [Workout(id: 10, name: 'Treino A'), Workout(id: 11, name: 'Treino B')];

  @override
  Future<List<PlanItem>> plan(int workoutId) async => const [
        PlanItem(id: 100, exerciseId: 1, sets: 3, reps: 12, position: 1, restSeconds: 60, targetLoad: 20),
        PlanItem(id: 101, exerciseId: 2, sets: 4, reps: 10, position: 2, notes: 'controlar a descida'),
      ];

  @override
  Future<List<Exercise>> exercises() async => const [
        Exercise(id: 1, name: 'Supino', muscleGroup: 'Peito'),
        Exercise(id: 2, name: 'Agachamento', muscleGroup: 'Pernas'),
      ];
}

/// Simula o servidor: uma lista de sessoes em memoria.
class FakeSessionRepository extends SessionRepository {
  FakeSessionRepository({List<WorkoutSession>? initial, this.failWith})
      : sessions = [...?initial],
        super(Dio());

  final List<WorkoutSession> sessions;
  AppException? failWith;
  int _nextSessionId = 500;
  int _nextPerformanceId = 900;
  final List<String> calls = [];

  void _maybeFail() {
    if (failWith != null) throw failWith!;
  }

  int _indexOf(int id) => sessions.indexWhere((s) => s.id == id);

  void _replace(int id, WorkoutSession Function(WorkoutSession) change) {
    final index = _indexOf(id);
    sessions[index] = change(sessions[index]);
  }

  @override
  Future<List<WorkoutSession>> history(int studentId) async {
    calls.add('history');
    return [...sessions.reversed];
  }

  @override
  Future<WorkoutSession> get(int sessionId) async => sessions[_indexOf(sessionId)];

  @override
  Future<WorkoutSession> start(int workoutId) async {
    _maybeFail();
    calls.add('start');
    final session = WorkoutSession(id: _nextSessionId++, workoutId: workoutId, startedAt: DateTime.now());
    sessions.add(session);
    return session;
  }

  @override
  Future<void> addPerformance(
    int sessionId, {
    required int workoutExerciseId,
    required int setNumber,
    required int reps,
    double? loadKg,
    Effort? effort,
  }) async {
    _maybeFail();
    calls.add('add:$workoutExerciseId#$setNumber');
    _replace(
      sessionId,
      (s) => WorkoutSession(
        id: s.id,
        workoutId: s.workoutId,
        startedAt: s.startedAt,
        finishedAt: s.finishedAt,
        performances: [
          ...s.performances,
          Performance(
            id: _nextPerformanceId++,
            workoutExerciseId: workoutExerciseId,
            setNumber: setNumber,
            reps: reps,
            loadKg: loadKg,
            effort: effort,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> updatePerformance(
    int sessionId,
    int performanceId, {
    required int setNumber,
    required int reps,
    double? loadKg,
    Effort? effort,
  }) async {
    _maybeFail();
    calls.add('update:$performanceId');
    _replace(
      sessionId,
      (s) => WorkoutSession(
        id: s.id,
        workoutId: s.workoutId,
        startedAt: s.startedAt,
        finishedAt: s.finishedAt,
        performances: [
          for (final p in s.performances)
            p.id == performanceId
                ? Performance(
                    id: p.id,
                    workoutExerciseId: p.workoutExerciseId,
                    setNumber: setNumber,
                    reps: reps,
                    loadKg: loadKg,
                    effort: effort,
                  )
                : p,
        ],
      ),
    );
  }

  @override
  Future<void> deletePerformance(int sessionId, int performanceId) async {
    _maybeFail();
    calls.add('delete:$performanceId');
    _replace(
      sessionId,
      (s) => WorkoutSession(
        id: s.id,
        workoutId: s.workoutId,
        startedAt: s.startedAt,
        finishedAt: s.finishedAt,
        performances: [for (final p in s.performances) if (p.id != performanceId) p],
      ),
    );
  }

  @override
  Future<void> finish(int sessionId) async {
    _maybeFail();
    calls.add('finish');
    _replace(
      sessionId,
      (s) => WorkoutSession(
        id: s.id,
        workoutId: s.workoutId,
        startedAt: s.startedAt,
        finishedAt: DateTime.now(),
        performances: s.performances,
      ),
    );
  }
}
