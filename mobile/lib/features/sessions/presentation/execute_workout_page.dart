import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/async_widgets.dart';
import '../../../core/utils/formatters.dart';
import '../../workouts/application/workout_providers.dart';
import '../../workouts/domain/workout.dart';
import '../../workouts/presentation/plan_summary.dart';
import '../application/session_providers.dart';
import '../domain/workout_session.dart';
import 'set_dialog.dart';

class ExecuteWorkoutPage extends ConsumerWidget {
  const ExecuteWorkoutPage({super.key, required this.workoutId});

  final int workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(workoutPlanProvider(workoutId));
    final execution = ref.watch(executionProvider(workoutId));
    final name = ref.watch(myWorkoutsProvider).value?.where((w) => w.id == workoutId).firstOrNull?.name;

    return Scaffold(
      appBar: AppBar(title: Text(name ?? 'Treino')),
      body: plan.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            ErrorRetry(error: error, onRetry: () => ref.invalidate(workoutPlanProvider(workoutId))),
        data: (rows) => execution.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              ErrorRetry(error: error, onRetry: () => ref.invalidate(executionProvider(workoutId))),
          data: (session) => session == null
              ? _NotStarted(workoutId: workoutId, rows: rows)
              : _InProgress(workoutId: workoutId, rows: rows, session: session),
        ),
      ),
    );
  }
}

class _NotStarted extends ConsumerWidget {
  const _NotStarted({required this.workoutId, required this.rows});

  final int workoutId;
  final List<PlanRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [for (final row in rows) PlanRowTile(row: row)],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              key: const Key('start-workout'),
              onPressed: () =>
                  runAction(context, () => ref.read(executionProvider(workoutId).notifier).start()),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar treino'),
            ),
          ),
        ),
      ],
    );
  }
}

class _InProgress extends ConsumerWidget {
  const _InProgress({required this.workoutId, required this.rows, required this.session});

  final int workoutId;
  final List<PlanRow> rows;
  final WorkoutSession session;

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar treino?'),
        content: const Text('Depois de finalizado, não será possível alterar as séries.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Voltar')),
          FilledButton(
            key: const Key('confirm-finish'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final done = await runAction(context, () => ref.read(executionProvider(workoutId).notifier).finish());
    if (done) {
      messenger.showSnackBar(const SnackBar(content: Text('Treino finalizado! Bom trabalho.')));
      router.go('/');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Iniciado em ${formatDateTime(session.startedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final row in rows)
                _ExerciseCard(workoutId: workoutId, row: row, sets: session.setsOf(row.item.id)),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              key: const Key('finish-workout'),
              onPressed: () => _finish(context, ref),
              icon: const Icon(Icons.check),
              label: const Text('Finalizar treino'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({required this.workoutId, required this.row, required this.sets});

  final int workoutId;
  final PlanRow row;
  final List<Performance> sets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(executionProvider(workoutId).notifier);
    final item = row.item;
    final done = sets.length >= item.sets;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(row.exerciseName, style: Theme.of(context).textTheme.titleMedium)),
                Chip(
                  key: Key('progress-${item.id}'),
                  avatar: Icon(done ? Icons.check_circle : Icons.timelapse, size: 18),
                  label: Text('${sets.length}/${item.sets}'),
                ),
              ],
            ),
            Text('Meta: ${describeTarget(item)}'),
            if (item.notes != null) Text(item.notes!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final performance in sets)
              ListTile(
                key: Key('set-${performance.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Série ${performance.setNumber}'),
                subtitle: Text('${performance.reps} repetições · ${formatLoad(performance.loadKg)}'),
                onTap: () async {
                  final input = await showSetDialog(
                    context,
                    title: 'Editar série ${performance.setNumber}',
                    initialReps: performance.reps,
                    initialLoad: performance.loadKg,
                  );
                  if (input != null && context.mounted) {
                    await runAction(
                      context,
                      () => controller.editSet(performance, reps: input.reps, loadKg: input.loadKg),
                    );
                  }
                },
                trailing: IconButton(
                  tooltip: 'Remover série',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => runAction(context, () => controller.removeSet(performance)),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: Key('add-set-${item.id}'),
                onPressed: () async {
                  final last = sets.isEmpty ? null : sets.last;
                  final input = await showSetDialog(
                    context,
                    title: 'Série ${sets.length + 1} · ${row.exerciseName}',
                    initialReps: last?.reps ?? item.reps,
                    initialLoad: last?.loadKg ?? item.targetLoad,
                  );
                  if (input != null && context.mounted) {
                    await runAction(
                      context,
                      () => controller.addSet(item.id, reps: input.reps, loadKg: input.loadKg),
                    );
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Registrar série'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
