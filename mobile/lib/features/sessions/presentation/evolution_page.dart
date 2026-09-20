import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_widgets.dart';
import '../../../core/utils/formatters.dart';
import '../application/evolution_providers.dart';
import '../domain/evolution.dart';
import 'sparkline.dart';

class EvolutionPage extends ConsumerWidget {
  const EvolutionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evolution = ref.watch(evolutionProvider);

    return evolution.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(evolutionProvider)),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.trending_up,
            message: 'Finalize alguns treinos para acompanhar sua evolução aqui.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(evolutionProvider.future),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) => _ExerciseCard(progress: items[index]),
          ),
        );
      },
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.progress});

  final ExerciseProgress progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final delta = progress.lastDeltaKg;

    return Card(
      key: Key('progress-${progress.exerciseName}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(progress.exerciseName, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (progress.bestLoadKg != null)
                  Text('Melhor: ${formatLoad(progress.bestLoadKg)}',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            if (progress.hasLoadData)
              Sparkline(
                values: [for (final p in progress.points) p.maxLoadKg ?? 0],
                color: scheme.primary,
              )
            else
              Text('${progress.points.length} sessões registradas (sem carga informada)',
                  key: const Key('no-load-data'), style: Theme.of(context).textTheme.bodySmall),
            if (delta != null && delta != 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(delta > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14, color: delta > 0 ? Colors.green : Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      '${delta > 0 ? '+' : ''}${formatLoad(delta)} desde a última sessão',
                      key: const Key('progress-delta'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
