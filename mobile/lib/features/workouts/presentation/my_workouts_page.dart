import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/async_widgets.dart';
import '../application/workout_providers.dart';

class MyWorkoutsPage extends ConsumerWidget {
  const MyWorkoutsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(myWorkoutsProvider);

    return workouts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(myWorkoutsProvider)),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.fitness_center,
            message: 'Você ainda não tem treinos.\nSeu personal vai atribuir um em breve.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(myWorkoutsProvider.future),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final workout = items[index];
              return Card(
                key: Key('workout-${workout.id}'),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
                  title: Text(workout.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/workouts/${workout.id}'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
