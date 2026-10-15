import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/async_widgets.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../workouts/domain/workout.dart';
import '../application/trainer_workouts_providers.dart';
import 'workout_pickers.dart';
import 'workout_sheets.dart';

/// Biblioteca de exercícios: catálogo comum (só leitura) e os exercícios criados pelo personal.
class ExerciseLibraryPage extends ConsumerStatefulWidget {
  const ExerciseLibraryPage({super.key});

  @override
  ConsumerState<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends ConsumerState<ExerciseLibraryPage> {
  final _search = TextEditingController();
  String? _group;
  bool _onlyMine = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Exercise exercise, List<Exercise> library) async {
    if (!exercise.custom) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercício do catálogo: não pode ser alterado. Crie um seu, se precisar.')),
      );
      return;
    }
    final result = await showExerciseForm(
      context,
      initialName: exercise.name,
      initialGroup: exercise.muscleGroup,
      groups: muscleGroupsOf(library),
    );
    if (result == null || !mounted) return;
    final repo = ref.read(trainerWorkoutsRepositoryProvider);
    if (result.delete) {
      final confirmed = await confirmAction(
        context,
        title: 'Excluir exercício?',
        message: '"${exercise.name}" sai da sua biblioteca. Exercícios usados em algum treino não podem ser excluídos.',
        action: 'Excluir',
        confirmKey: const Key('confirm-delete-exercise'),
      );
      if (!confirmed || !mounted) return;
      if (await runAction(context, () => repo.deleteExercise(exercise.id))) ref.invalidate(exerciseLibraryProvider);
      return;
    }
    if (await runAction(context, () => repo.updateExercise(exercise.id, result.name, result.muscleGroup))) {
      ref.invalidate(exerciseLibraryProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(exerciseLibraryProvider);

    return Scaffold(
      body: SafeArea(
        child: library.when(
          loading: () => const SkeletonList(heights: [56, 44, 60, 60, 60]),
          error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(exerciseLibraryProvider)),
          data: (items) {
            final groups = {for (final e in items) if ((e.muscleGroup ?? '').trim().isNotEmpty) e.muscleGroup!.trim()}.toList()..sort();
            final mine = items.where((e) => e.custom).length;
            final query = _search.text.trim().toLowerCase();
            final visible = [
              for (final e in items)
                if ((query.isEmpty || e.name.toLowerCase().contains(query)) &&
                    (_group == null || e.muscleGroup?.trim() == _group) &&
                    (!_onlyMine || e.custom))
                  e,
            ];

            return RefreshIndicator(
              onRefresh: () async => ref.refresh(exerciseLibraryProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 24),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleIconButton(
                        icon: LucideIcons.arrowLeft,
                        tooltip: 'Voltar',
                        onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                      ),
                      CircleIconButton(
                        key: const Key('new-exercise'),
                        icon: LucideIcons.plus,
                        tooltip: 'Novo exercício',
                        onPressed: () => createExerciseFlow(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('EXERCÍCIOS', style: AppText.display(36).copyWith(letterSpacing: 0.7)),
                  Text(
                    '${items.length} na biblioteca · ${mine == 1 ? '1 criado por você' : '$mine criados por você'}',
                    key: const Key('library-count'),
                    style: AppText.body(size: 13.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('library-search'),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: 'Buscar exercício', prefixIcon: Icon(LucideIcons.search, size: 18)),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        FilterChip(
                          key: const Key('library-only-mine'),
                          label: const Text('Meus'),
                          selected: _onlyMine,
                          onSelected: (v) => setState(() => _onlyMine = v),
                        ),
                        const SizedBox(width: 6),
                        for (final g in [null, ...groups]) ...[
                          ChoiceChip(
                            label: Text(g ?? 'Todos'),
                            selected: _group == g,
                            onSelected: (_) => setState(() => _group = g),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyState(icon: LucideIcons.library, message: 'A biblioteca está vazia.\nToque em + para criar um exercício.'),
                    )
                  else if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Center(
                        child: Text('Nenhum exercício encontrado.', key: const Key('library-none'), style: AppText.body(color: AppColors.textMuted)),
                      ),
                    )
                  else
                    for (final e in visible)
                      ExerciseRow(
                        exercise: e,
                        onTap: () => _open(e, items),
                        trailing: e.custom
                            ? null
                            : const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(LucideIcons.lock, size: 16, color: AppColors.textMuted),
                              ),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
