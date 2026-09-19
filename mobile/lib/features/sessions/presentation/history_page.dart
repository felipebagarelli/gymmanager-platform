import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_widgets.dart';
import '../../../core/utils/formatters.dart';
import '../../workouts/application/workout_providers.dart';
import '../application/session_providers.dart';
import '../domain/workout_session.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(historyProvider)),
      data: (sessions) {
        if (sessions.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            message: 'Você ainda não executou nenhum treino.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(historyProvider.future),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) => _SessionTile(session: sessions[index]),
          ),
        );
      },
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutName = ref
            .watch(myWorkoutsProvider)
            .value
            ?.where((w) => w.id == session.workoutId)
            .firstOrNull
            ?.name ??
        'Treino #${session.workoutId}';
    final finished = session.finishedAt;

    return Card(
      child: ExpansionTile(
        key: Key('session-${session.id}'),
        title: Text(workoutName),
        subtitle: Text([
          formatDateTime(session.startedAt),
          finished == null ? 'Em andamento' : formatDuration(session.startedAt, finished),
        ].join(' · ')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (session.performances.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Nenhuma série registrada.'),
            )
          else
            _Sets(session: session),
        ],
      ),
    );
  }
}

class _Sets extends ConsumerWidget {
  const _Sets({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(workoutPlanProvider(session.workoutId));
    final names = <int, String>{
      for (final row in plan.value ?? const []) row.item.id: row.exerciseName,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final performance in session.performances)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${names[performance.workoutExerciseId] ?? 'Exercício'} · '
              'série ${performance.setNumber}: ${performance.reps} rep · ${formatLoad(performance.loadKg)}',
            ),
          ),
      ],
    );
  }
}
