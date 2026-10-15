import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/async_widgets.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../workouts/domain/workout.dart';
import '../../students/application/students_providers.dart';
import '../application/trainer_workouts_providers.dart';
import '../domain/workout_draft.dart';
import 'workout_sheets.dart';

/// Grupos para sugerir: os padrão + os que já existem na biblioteca.
List<String> muscleGroupsOf(List<Exercise> library) {
  final groups = <String>[...defaultMuscleGroups];
  for (final e in library) {
    final g = e.muscleGroup?.trim();
    if (g != null && g.isNotEmpty && !groups.any((x) => x.toLowerCase() == g.toLowerCase())) groups.add(g);
  }
  return groups;
}

/// Cria um exercício do personal pelo formulário. Retorna o exercício criado (ou null).
Future<Exercise?> createExerciseFlow(BuildContext context, WidgetRef ref) async {
  final library = ref.read(exerciseLibraryProvider).value ?? const <Exercise>[];
  final result = await showExerciseForm(context, groups: muscleGroupsOf(library));
  if (result == null || result.delete || !context.mounted) return null;
  Exercise? created;
  final ok = await runAction(context, () async {
    created = await ref.read(trainerWorkoutsRepositoryProvider).createExercise(result.name, result.muscleGroup);
  });
  if (ok) ref.invalidate(exerciseLibraryProvider);
  return created;
}

// ---------------------------------------------------------------- escolher exercício

/// Lista da biblioteca para escolher o exercício que entra no treino.
Future<Exercise?> showExercisePicker(BuildContext context) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _ExercisePicker(),
  );
}

class _ExercisePicker extends ConsumerStatefulWidget {
  const _ExercisePicker();

  @override
  ConsumerState<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<_ExercisePicker> {
  final _search = TextEditingController();
  String? _group;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final created = await createExerciseFlow(context, ref);
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(exerciseLibraryProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: Text('ESCOLHER EXERCÍCIO', style: AppText.display(28))),
                  TextButton.icon(
                    key: const Key('picker-new-exercise'),
                    onPressed: _create,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Novo'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                key: const Key('picker-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Buscar exercício', prefixIcon: Icon(LucideIcons.search, size: 18)),
              ),
            ),
            Expanded(
              child: library.when(
                loading: () => const SkeletonList(heights: [44, 60, 60, 60]),
                error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(exerciseLibraryProvider)),
                data: (items) {
                  final groups = {for (final e in items) if ((e.muscleGroup ?? '').trim().isNotEmpty) e.muscleGroup!.trim()}.toList()..sort();
                  final query = _search.text.trim().toLowerCase();
                  final visible = [
                    for (final e in items)
                      if ((query.isEmpty || e.name.toLowerCase().contains(query)) && (_group == null || e.muscleGroup?.trim() == _group)) e,
                  ];
                  return Column(
                    children: [
                      if (groups.isNotEmpty)
                        SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
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
                      Expanded(
                        child: visible.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    items.isEmpty ? 'A biblioteca está vazia. Toque em "Novo" para criar um exercício.' : 'Nenhum exercício encontrado.',
                                    textAlign: TextAlign.center,
                                    style: AppText.body(color: AppColors.textMuted),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                                itemCount: visible.length,
                                itemBuilder: (context, i) => ExerciseRow(
                                  exercise: visible[i],
                                  onTap: () => Navigator.of(context).pop(visible[i]),
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linha de exercício da biblioteca (no picker e na página da biblioteca).
class ExerciseRow extends StatelessWidget {
  const ExerciseRow({super.key, required this.exercise, required this.onTap, this.trailing});

  final Exercise exercise;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        key: Key('exercise-${exercise.id}'),
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.name, style: AppText.body(size: 15.5, weight: FontWeight.w600)),
                  if ((exercise.muscleGroup ?? '').isNotEmpty)
                    Text(exercise.muscleGroup!, style: AppText.body(size: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (exercise.custom) const TagChip('Seu'),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- atribuir

/// Escolhe alunos ativos para receber o treino. Atribui e devolve quantos receberam.
Future<int> showAssignStudents(BuildContext context, {required int workoutId, required Set<int> alreadyAssigned}) async {
  final assigned = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AssignStudents(workoutId: workoutId, alreadyAssigned: alreadyAssigned),
  );
  return assigned ?? 0;
}

class _AssignStudents extends ConsumerStatefulWidget {
  const _AssignStudents({required this.workoutId, required this.alreadyAssigned});

  final int workoutId;
  final Set<int> alreadyAssigned;

  @override
  ConsumerState<_AssignStudents> createState() => _AssignStudentsState();
}

class _AssignStudentsState extends ConsumerState<_AssignStudents> {
  final _selected = <int>{};
  bool _saving = false;

  Future<void> _assign() async {
    setState(() => _saving = true);
    final repo = ref.read(trainerWorkoutsRepositoryProvider);
    var done = 0;
    final ok = await runAction(context, () async {
      for (final id in _selected) {
        await repo.assign(widget.workoutId, id);
        done++;
        ref.invalidate(studentWorkoutsProvider(id));
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok || done > 0) Navigator.of(context).pop(done);
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(trainerStudentsProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('ATRIBUIR A ALUNOS', style: AppText.display(28)),
          ),
          Expanded(
            child: students.when(
              loading: () => const SkeletonList(heights: [60, 60, 60]),
              error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(trainerStudentsProvider)),
              data: (items) {
                final available = [for (final s in items) if (s.active && !widget.alreadyAssigned.contains(s.id)) s];
                if (available.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        items.isEmpty ? 'Você ainda não tem alunos.' : 'Todos os alunos ativos já estão com este treino.',
                        key: const Key('assign-none'),
                        textAlign: TextAlign.center,
                        style: AppText.body(color: AppColors.textMuted),
                      ),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  children: [
                    for (final s in available)
                      CheckboxListTile(
                        key: Key('assign-student-${s.id}'),
                        value: _selected.contains(s.id),
                        onChanged: (v) => setState(() => v == true ? _selected.add(s.id) : _selected.remove(s.id)),
                        secondary: InitialsAvatar(name: s.name, size: 38),
                        title: Text(s.name, style: AppText.body(size: 15.5, weight: FontWeight.w600)),
                        activeColor: AppColors.volt,
                        checkColor: AppColors.onVolt,
                      ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: PillButton(
                key: const Key('assign-confirm'),
                label: _selected.isEmpty
                    ? 'Escolha os alunos'
                    : (_selected.length == 1 ? 'Atribuir a 1 aluno' : 'Atribuir a ${_selected.length} alunos'),
                onPressed: _selected.isEmpty || _saving ? null : _assign,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// No perfil do aluno: escolhe um treino do personal para atribuir. Retorna true se atribuiu.
Future<bool> showAssignWorkout(BuildContext context, {required int studentId, required Set<int> alreadyAssigned}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AssignWorkout(studentId: studentId, alreadyAssigned: alreadyAssigned),
  );
  return ok == true;
}

class _AssignWorkout extends ConsumerWidget {
  const _AssignWorkout({required this.studentId, required this.alreadyAssigned});

  final int studentId;
  final Set<int> alreadyAssigned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(trainerWorkoutsProvider);

    Future<void> assign(Workout w) async {
      final ok = await runAction(context, () => ref.read(trainerWorkoutsRepositoryProvider).assign(w.id, studentId));
      if (!ok || !context.mounted) return;
      refreshAssignments(ref, workoutId: w.id, studentId: studentId);
      Navigator.of(context).pop(true);
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('ATRIBUIR TREINO', style: AppText.display(28)),
          ),
          Expanded(
            child: workouts.when(
              loading: () => const SkeletonList(heights: [60, 60, 60]),
              error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(trainerWorkoutsProvider)),
              data: (items) {
                final available = [for (final w in items) if (!alreadyAssigned.contains(w.id)) w];
                if (available.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        items.isEmpty ? 'Você ainda não criou treinos. Monte um na aba Treinos.' : 'Todos os seus treinos já estão com este aluno.',
                        key: const Key('assign-workout-none'),
                        textAlign: TextAlign.center,
                        style: AppText.body(color: AppColors.textMuted),
                      ),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    for (final w in available)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          key: Key('assign-workout-${w.id}'),
                          radius: 16,
                          padding: const EdgeInsets.all(14),
                          onTap: () => assign(w),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.dumbbell, size: 20, color: AppColors.volt),
                              const SizedBox(width: 12),
                              Expanded(child: Text(w.name, style: AppText.body(size: 15.5, weight: FontWeight.w600))),
                              Text(exerciseCountLabel(w.exerciseCount), style: AppText.body(size: 13, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String exerciseCountLabel(int? count) => switch (count) {
      null => '',
      0 => 'Sem exercícios',
      1 => '1 exercício',
      _ => '$count exercícios',
    };
