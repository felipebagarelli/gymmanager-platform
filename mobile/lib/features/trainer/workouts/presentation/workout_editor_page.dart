import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../workouts/presentation/weekdays.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/async_widgets.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../workouts/domain/plan_stats.dart';
import '../../../workouts/domain/workout.dart';
import '../../../workouts/domain/workout_name.dart';
import '../application/trainer_workouts_providers.dart';
import '../domain/workout_draft.dart';
import 'workout_pickers.dart';
import 'trainer_workouts_page.dart';
import 'workout_sheets.dart';

enum _MenuAction { rename, duplicate, delete }

/// Montagem de um treino no celular: exercícios (adicionar, ajustar, arrastar para ordenar,
/// retirar) e os alunos que estão com ele.
class WorkoutEditorPage extends ConsumerWidget {
  const WorkoutEditorPage({super.key, required this.workoutId, this.studentMode = false});

  final int workoutId;

  /// Aluno sem personal no próprio treino: sem atribuir a alunos e só com o catálogo.
  final bool studentMode;

  void _back(BuildContext context) => context.canPop() ? context.pop() : context.go('/');

  Future<void> _onMenu(BuildContext context, WidgetRef ref, Workout workout, _MenuAction action) async {
    final repo = ref.read(trainerWorkoutsRepositoryProvider);
    switch (action) {
      case _MenuAction.rename:
        final name = await promptWorkoutName(context, initial: workout.name, title: 'Renomear treino', action: 'Salvar');
        if (name == null || name == workout.name || !context.mounted) return;
        if (await runAction(context, () => repo.rename(workout.id, name))) {
          ref.invalidate(trainerWorkoutsProvider);
          ref.invalidate(workoutByIdProvider(workout.id));
        }
      case _MenuAction.duplicate:
        Workout? copy;
        final ok = await runAction(context, () async => copy = await repo.duplicate(workout.id));
        if (!ok || copy == null || !context.mounted) return;
        ref.invalidate(trainerWorkoutsProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cópia criada. Ajuste o que precisar.')));
        context.pushReplacement(studentMode ? studentEditorPath(copy!.id) : trainerEditorPath(copy!.id));
      case _MenuAction.delete:
        final confirmed = await confirmAction(
          context,
          title: 'Excluir treino?',
          message: studentMode
              ? 'O treino "${workout.name}" sai da sua lista. Se você já treinou com ele, o histórico continua.'
              : 'O treino "${workout.name}" será apagado. Treinos que já foram de algum aluno não podem ser excluídos.',
          action: 'Excluir',
          confirmKey: const Key('confirm-delete-workout'),
        );
        if (!confirmed || !context.mounted) return;
        if (await runAction(context, () => repo.delete(workout.id))) {
          ref.invalidate(trainerWorkoutsProvider);
          if (context.mounted) _back(context);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(trainerWorkoutsProvider);
    final plan = ref.watch(workoutPlanEditorProvider(workoutId));

    return Scaffold(
      body: SafeArea(
        child: workouts.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => const SkeletonList(heights: [56, 80, 72, 72, 72]),
          error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(trainerWorkoutsProvider)),
          data: (items) {
            // fora da lista do personal: pode ser um treino que o aluno dele montou
            final own = items.where((w) => w.id == workoutId).firstOrNull;
            final workout = own ?? (studentMode ? null : ref.watch(workoutByIdProvider(workoutId)).value);
            if (workout == null && !studentMode && ref.watch(workoutByIdProvider(workoutId)).isLoading) {
              return const SkeletonList(heights: [56, 80, 72, 72, 72]);
            }
            if (workout == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(kScreenPadding),
                    child: CircleIconButton(icon: LucideIcons.arrowLeft, tooltip: 'Voltar', onPressed: () => _back(context)),
                  ),
                  const Expanded(child: EmptyState(icon: LucideIcons.dumbbell, message: 'Treino não encontrado.')),
                ],
              );
            }
            return plan.when(
              skipLoadingOnRefresh: true,
              skipLoadingOnReload: true,
              loading: () => const SkeletonList(heights: [56, 80, 72, 72, 72]),
              error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(workoutPlanEditorProvider(workoutId))),
              data: (planItems) => _Editor(
                studentMode: studentMode,
                fromStudent: !studentMode && own == null,
                workout: workout,
                items: planItems,
                onBack: () => _back(context),
                onMenu: (action) => _onMenu(context, ref, workout, action),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Editor extends ConsumerWidget {
  const _Editor({
    required this.workout,
    required this.items,
    required this.onBack,
    required this.onMenu,
    this.studentMode = false,
    this.fromStudent = false,
  });

  final bool studentMode;

  /// O personal abriu um treino que o aluno dele montou.
  final bool fromStudent;

  final Workout workout;
  final List<PlanItem> items;
  final VoidCallback onBack;
  final ValueChanged<_MenuAction> onMenu;

  bool get _ownMenu => !fromStudent;

  WorkoutPlanController _plan(WidgetRef ref) => ref.read(workoutPlanEditorProvider(workout.id).notifier);

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final exercise = await showExercisePicker(context, allowCreate: !studentMode);
    if (exercise == null || !context.mounted) return;
    final result = await showPlanItemSheet(
      context,
      exerciseName: exercise.name,
      muscleGroup: exercise.muscleGroup,
      initial: PlanItemDraft(exerciseId: exercise.id),
    );
    final draft = result?.draft;
    if (draft == null || !context.mounted) return;
    await runAction(context, () => _plan(ref).add(draft));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, PlanItem item) async {
    final result = await showPlanItemSheet(
      context,
      exerciseName: item.exerciseName ?? 'Exercício',
      muscleGroup: item.muscleGroup,
      initial: PlanItemDraft.fromItem(item),
      editing: true,
    );
    if (result == null || !context.mounted) return;
    if (result.remove) {
      await runAction(context, () => _plan(ref).remove(item));
    } else if (result.draft != null) {
      await runAction(context, () => _plan(ref).edit(item, result.draft!));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = splitWorkoutName(workout.name);
    final stats = PlanStats.from([
      for (final i in items) PlanRow(item: i, exerciseName: i.exerciseName ?? 'Exercício', muscleGroup: i.muscleGroup),
    ]);
    final summary = items.isEmpty
        ? 'Nenhum exercício ainda'
        : '${exerciseCountLabel(stats.exercises)} · ${stats.sets} séries · ~${stats.estimatedMinutes} min';

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 24),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorderItem: (oldIndex, newIndex) => runAction(context, () => _plan(ref).move(oldIndex, newIndex)),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleIconButton(icon: LucideIcons.arrowLeft, tooltip: 'Voltar', onPressed: onBack),
              PopupMenuButton<_MenuAction>(
                key: const Key('workout-menu'),
                tooltip: 'Mais opções',
                icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
                onSelected: onMenu,
                // o personal edita o treino que o aluno montou, mas não duplica nem exclui
                itemBuilder: (context) => [
                  const PopupMenuItem(key: Key('workout-rename'), value: _MenuAction.rename, child: Text('Renomear')),
                  if (_ownMenu) ...const [
                    PopupMenuItem(key: Key('workout-duplicate'), value: _MenuAction.duplicate, child: Text('Duplicar')),
                    PopupMenuItem(key: Key('workout-delete'), value: _MenuAction.delete, child: Text('Excluir')),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (name.tag != null) LabelText(name.tag!, color: AppColors.volt),
          Text(name.title.toUpperCase(), key: const Key('workout-title'), style: AppText.display(34)),
          Text(summary, key: const Key('workout-summary'), style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          const SectionTitle('Exercícios'),
          if (items.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Toque para ajustar. Arraste pela alça para mudar a ordem.',
                  style: AppText.body(size: 12.5, color: AppColors.textMuted)),
            ),
        ],
      ),
      itemBuilder: (context, i) => _PlanItemCard(
        key: ValueKey(items[i].id),
        index: i,
        item: items[i],
        onTap: () => _edit(context, ref, items[i]),
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          PillButton(
            key: const Key('add-exercise'),
            label: 'Adicionar exercício',
            icon: LucideIcons.plus,
            style: items.isEmpty ? PillStyle.volt : PillStyle.ghost,
            height: 50,
            onPressed: () => _add(context, ref),
          ),
          const SizedBox(height: 24),
          if (!studentMode && !fromStudent) _Assignees(workoutId: workout.id),
          if (fromStudent)
            Text('Treino montado pelo aluno. Você pode ajustar os exercícios; só ele pode excluir.',
                key: const Key('student-owned-note'), style: AppText.body(size: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _PlanItemCard extends StatelessWidget {
  const _PlanItemCard({super.key, required this.index, required this.item, required this.onTap});

  final int index;
  final PlanItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        key: Key('plan-item-${item.id}'),
        radius: 16,
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(10)),
              child: Text('${index + 1}', style: AppText.display(18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.exerciseName ?? 'Exercício', style: AppText.body(size: 15.5, weight: FontWeight.w600)),
                  Text(planItemSummary(item), style: AppText.body(size: 13, color: AppColors.textSecondary)),
                  if ((item.notes ?? '').trim().isNotEmpty)
                    Text(item.notes!.trim(),
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Semantics(
                label: 'Arrastar para mudar a ordem',
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(LucideIcons.gripVertical, size: 20, color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alunos com o treino ativo, com atalhos para atribuir e retirar.
class _Assignees extends ConsumerWidget {
  const _Assignees({required this.workoutId});

  final int workoutId;

  Future<void> _unassign(BuildContext context, WidgetRef ref, int studentId, String name) async {
    final confirmed = await confirmAction(
      context,
      title: 'Retirar treino?',
      message: '$name deixa de ver este treino. O histórico de sessões continua.',
      action: 'Retirar',
      confirmKey: const Key('confirm-unassign'),
    );
    if (!confirmed || !context.mounted) return;
    final ok = await runAction(context, () => ref.read(trainerWorkoutsRepositoryProvider).unassign(workoutId, studentId));
    if (ok) refreshAssignments(ref, workoutId: workoutId, studentId: studentId);
  }

  Future<void> _editDays(BuildContext context, WidgetRef ref, WorkoutAssignee a) async {
    final days = await showWeekdaysPicker(context, title: 'Dias de ${a.studentName.split(' ').first}', initial: {...a.weekdays});
    if (days == null || !context.mounted) return;
    final ok = await runAction(context, () => ref.read(trainerWorkoutsRepositoryProvider).setWeekdays(workoutId, a.studentId, days));
    if (ok) refreshAssignments(ref, workoutId: workoutId, studentId: a.studentId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignees = ref.watch(workoutAssigneesProvider(workoutId));
    final current = assignees.value ?? const <WorkoutAssignee>[];

    Future<void> assign() async {
      final count = await showAssignStudents(context, workoutId: workoutId, alreadyAssigned: {for (final a in current) a.studentId});
      if (count > 0) refreshAssignments(ref, workoutId: workoutId);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Alunos com este treino', action: 'Atribuir', onAction: assign),
        assignees.when(
          loading: () => const SkeletonBox(height: 56),
          error: (error, _) => Text(messageOf(error), style: AppText.body(color: AppColors.textMuted)),
          data: (items) => items.isEmpty
              ? Text('Nenhum aluno com este treino ainda.', key: const Key('no-assignees'), style: AppText.body(color: AppColors.textMuted))
              : Column(
                  children: [
                    for (final a in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          key: Key('assignee-${a.studentId}'),
                          radius: 16,
                          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                          onTap: () => context.push('/trainer/students/${a.studentId}'),
                          child: Row(
                            children: [
                              InitialsAvatar(name: a.studentName, size: 38),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.studentName, style: AppText.body(size: 15, weight: FontWeight.w600)),
                                    Text(
                                      a.weekdays.isEmpty ? 'Sem dia definido' : formatWeekdays(a.weekdays),
                                      key: Key('assignee-days-text-${a.studentId}'),
                                      style: AppText.body(
                                        size: 12.5,
                                        weight: FontWeight.w500,
                                        color: a.weekdays.isEmpty ? AppColors.textMuted : AppColors.volt,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                key: Key('assignee-days-${a.studentId}'),
                                tooltip: 'Dias da semana de ${a.studentName}',
                                icon: const Icon(LucideIcons.calendarDays, size: 18, color: AppColors.textSecondary),
                                onPressed: () => _editDays(context, ref, a),
                              ),
                              IconButton(
                                key: Key('unassign-${a.studentId}'),
                                tooltip: 'Retirar treino de ${a.studentName}',
                                icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textMuted),
                                onPressed: () => _unassign(context, ref, a.studentId, a.studentName),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
