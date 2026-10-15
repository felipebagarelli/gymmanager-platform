import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/session_repository.dart';
import '../domain/completion.dart';
import '../domain/training_stats.dart';
import '../domain/workout_session.dart';

final sessionRepositoryProvider =
    Provider<SessionRepository>((ref) => SessionRepository(ref.watch(dioProvider)));

/// Historico de sessoes do aluno logado (mais recentes primeiro).
final historyProvider = FutureProvider<List<WorkoutSession>>((ref) async {
  final profile = ref.watch(currentStudentProvider);
  if (profile == null) return const [];
  return ref.watch(sessionRepositoryProvider).history(profile.id);
});

/// Estado da execucao de um treino: a sessao em andamento, ou null se nao
/// houver (ainda nao iniciada). Os metodos lancam AppException em caso de erro
/// e mantem o estado anterior, para a tela mostrar a mensagem.
class ExecutionController extends AsyncNotifier<WorkoutSession?> {
  ExecutionController(this.workoutId);

  final int workoutId;

  @override
  Future<WorkoutSession?> build() async {
    final history = await ref.watch(historyProvider.future);
    for (final session in history) {
      if (session.workoutId == workoutId && session.isOpen) return session;
    }
    return null;
  }

  SessionRepository get _repository => ref.read(sessionRepositoryProvider);

  WorkoutSession get _open {
    final session = state.value;
    if (session == null) throw StateError('Nenhuma sessão em andamento');
    return session;
  }

  Future<void> start() async {
    final session = await _repository.start(workoutId);
    state = AsyncData(session);
    ref.invalidate(historyProvider);
  }

  Future<void> addSet(int workoutExerciseId, {required int reps, double? loadKg, Effort? effort}) async {
    final session = _open;
    final existing = session.setsOf(workoutExerciseId);
    // maior numero + 1 (e nao a contagem): o servidor nao renumera apos remocoes
    final setNumber = existing.isEmpty ? 1 : existing.last.setNumber + 1;
    await _repository.addPerformance(
      session.id,
      workoutExerciseId: workoutExerciseId,
      setNumber: setNumber,
      reps: reps,
      loadKg: loadKg,
      effort: effort,
    );
    await _refresh(session.id);
  }

  Future<void> editSet(Performance performance, {required int reps, double? loadKg, Effort? effort}) async {
    final session = _open;
    await _repository.updatePerformance(
      session.id,
      performance.id,
      setNumber: performance.setNumber,
      reps: reps,
      loadKg: loadKg,
      effort: effort,
    );
    await _refresh(session.id);
  }

  Future<void> removeSet(Performance performance) async {
    final session = _open;
    await _repository.deletePerformance(session.id, performance.id);
    await _refresh(session.id);
  }

  /// Finaliza e devolve a sessão com as séries e o horário de término (para o resumo).
  Future<WorkoutSession> finish() async {
    final session = _open;
    await _repository.finish(session.id);
    state = const AsyncData(null);
    ref.invalidate(historyProvider);
    return WorkoutSession(
      id: session.id,
      workoutId: session.workoutId,
      startedAt: session.startedAt,
      finishedAt: ref.read(clockProvider)(),
      performances: session.performances,
    );
  }

  Future<void> _refresh(int sessionId) async {
    state = AsyncData(await _repository.get(sessionId));
  }
}

final executionProvider =
    AsyncNotifierProvider.family<ExecutionController, WorkoutSession?, int>(
  ExecutionController.new,
);

/// Números da home (semana, sequência, "treinou hoje"); null enquanto o histórico carrega.
final trainingStatsProvider = Provider<TrainingStats?>((ref) {
  final history = ref.watch(historyProvider).value;
  return history == null ? null : TrainingStats.from(history);
});

/// Resumo do último treino finalizado, lido pela tela "Treino concluído".
class CompletedWorkoutController extends Notifier<WorkoutCompletion?> {
  @override
  WorkoutCompletion? build() => null;

  void set(WorkoutCompletion? value) => state = value;
}

final completedWorkoutProvider =
    NotifierProvider<CompletedWorkoutController, WorkoutCompletion?>(CompletedWorkoutController.new);
