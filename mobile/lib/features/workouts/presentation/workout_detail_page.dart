import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/async_widgets.dart';
import '../../sessions/application/session_providers.dart';
import '../application/workout_providers.dart';
import 'plan_summary.dart';

class WorkoutDetailPage extends ConsumerWidget {
  const WorkoutDetailPage({super.key, required this.workoutId});

  final int workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(workoutPlanProvider(workoutId));
    final name = ref.watch(myWorkoutsProvider).value?.where((w) => w.id == workoutId).firstOrNull?.name;
    final hasOpenSession = ref.watch(executionProvider(workoutId)).value != null;

    return Scaffold(
      appBar: AppBar(title: Text(name ?? 'Treino')),
      body: plan.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            ErrorRetry(error: error, onRetry: () => ref.invalidate(workoutPlanProvider(workoutId))),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: Icons.list_alt,
              message: 'Este treino ainda não tem exercícios.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [for (final row in rows) PlanRowTile(row: row)],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const Key('open-execution'),
            onPressed: (plan.value?.isNotEmpty ?? false)
                ? () => context.push('/workouts/$workoutId/run')
                : null,
            icon: Icon(hasOpenSession ? Icons.play_arrow : Icons.flag),
            label: Text(hasOpenSession ? 'Continuar treino' : 'Iniciar treino'),
          ),
        ),
      ),
    );
  }
}
