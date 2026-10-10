import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../../workouts/application/workout_providers.dart';
import '../../workouts/domain/workout.dart';
import '../../workouts/domain/workout_name.dart';
import '../application/evolution_providers.dart';
import '../application/session_providers.dart';
import '../domain/completion.dart';
import '../domain/workout_session.dart';
import 'elapsed_clock.dart';
import 'exercise_cards.dart';
import 'rest_view.dart';
import 'set_sheet.dart';

/// Execução do treino (tela de fluxo, sem tab bar): cronômetro, progresso, exercício em foco
/// e, depois de cada série salva, a tela de descanso. Quem registra é o aluno; o personal só lê.
class ExecuteWorkoutPage extends ConsumerStatefulWidget {
  const ExecuteWorkoutPage({super.key, required this.workoutId});

  final int workoutId;

  @override
  ConsumerState<ExecuteWorkoutPage> createState() => _ExecuteWorkoutPageState();
}

class _ExecuteWorkoutPageState extends ConsumerState<ExecuteWorkoutPage> {
  /// Exercício escolhido pelo aluno; null = o primeiro que ainda tem série pendente.
  int? _selectedItemId;

  /// Descanso em andamento (substitui a tela de execução enquanto existir).
  RestPlan? _rest;

  int get _workoutId => widget.workoutId;

  PlanRow _activeRow(List<PlanRow> rows, WorkoutSession session) {
    final selected = rows.where((r) => r.item.id == _selectedItemId).firstOrNull;
    if (selected != null) return selected;
    return rows.where((r) => session.setsOf(r.item.id).length < r.item.sets).firstOrNull ?? rows.last;
  }

  String _loadText(double? load) => load == null ? '' : ' × ${formatNumber(load)} kg';

  Future<void> _register(PlanRow row, WorkoutSession session) async {
    final item = row.item;
    final sets = session.setsOf(item.id);
    final last = sets.isEmpty ? null : sets.last;
    final history = ref.read(historyProvider).value ?? const [];
    final before = lastPerformanceOf(history, item.id, exceptSessionId: session.id);

    final subtitle = [
      'Meta ${item.reps}${_loadText(item.targetLoad)}',
      if (before != null) 'última vez ${before.reps}${_loadText(before.loadKg)}',
    ].join(' · ');

    final result = await showSetSheet(
      context,
      title: 'Série ${sets.length + 1} · ${row.exerciseName}',
      subtitle: subtitle,
      // pré-preenche com a série anterior desta sessão ou, na primeira, com a meta
      initialReps: last?.reps ?? item.reps,
      initialLoad: last?.loadKg ?? item.targetLoad ?? 0,
    );
    if (result == null || !mounted) return;

    final saved = await runAction(
      context,
      () => ref
          .read(executionProvider(_workoutId).notifier)
          .addSet(item.id, reps: result.reps, loadKg: result.loadKg, effort: result.effort),
    );
    if (saved && mounted) _afterSave(row, sets.length + 1, result);
  }

  /// Decide o que vem depois de salvar: descanso, ou o aviso de treino completo.
  void _afterSave(PlanRow row, int setNumber, SetSheetResult saved) {
    final rows = ref.read(workoutPlanProvider(_workoutId)).value ?? const <PlanRow>[];
    final session = ref.read(executionProvider(_workoutId)).value;
    if (session == null) return;

    bool pending(PlanRow r) => session.setsOf(r.item.id).length < r.item.sets;
    final stillPendingHere = pending(row);
    // continua no mesmo exercício até completá-lo; depois vai para o primeiro pendente
    final next = stillPendingHere ? row : rows.where(pending).firstOrNull;

    setState(() => _selectedItemId = stillPendingHere ? row.item.id : null);

    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todas as séries feitas. Finalize o treino.')),
      );
      return;
    }

    final seconds = row.item.restSeconds ?? 60;
    if (seconds <= 0) return; // sem descanso configurado: segue direto

    final nextNumber = session.setsOf(next.item.id).length + 1;
    setState(() {
      _rest = RestPlan(
        savedMessage: 'Série $setNumber de ${row.exerciseName} salva · '
            '${saved.reps}${saved.loadKg == null ? ' reps' : _loadText(saved.loadKg)}',
        totalSeconds: seconds,
        nextTitle: '${next.exerciseName} · Série $nextNumber',
        nextDetail: 'Meta ${next.item.reps}${_loadText(next.item.targetLoad)}',
        nextGroup: next.muscleGroup,
      );
    });
  }

  Future<void> _edit(PlanRow row, WorkoutSession session, Performance performance) async {
    final controller = ref.read(executionProvider(_workoutId).notifier);
    final result = await showSetSheet(
      context,
      title: 'Editar série ${performance.setNumber} · ${row.exerciseName}',
      subtitle: 'Meta ${row.item.reps}${_loadText(row.item.targetLoad)}',
      initialReps: performance.reps,
      initialLoad: performance.loadKg ?? 0,
      initialEffort: performance.effort,
      editing: true,
    );
    if (result == null || !mounted) return;

    if (result.remove) {
      await runAction(context, () => controller.removeSet(performance));
    } else {
      await runAction(
        context,
        () => controller.editSet(performance, reps: result.reps, loadKg: result.loadKg, effort: result.effort),
      );
    }
  }

  Future<void> _finish(List<PlanRow> rows, WorkoutSession session) async {
    final planned = rows.fold<int>(0, (sum, r) => sum + r.item.sets);
    final done = rows.fold<int>(0, (sum, r) => sum + session.setsOf(r.item.id).length.clamp(0, r.item.sets));
    final missing = planned - done;

    // com todas as séries feitas finaliza direto; senão, confirma antes
    if (missing > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Finalizar treino?'),
          content: Text(
            '${session.performances.isEmpty ? 'Você ainda não registrou nenhuma série.' : 'Faltam $missing ${missing == 1 ? 'série' : 'séries'}.'} '
            'Depois de finalizado, não será possível alterar as séries.',
          ),
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
      if (confirmed != true || !mounted) return;
    }

    // lê o histórico e os nomes ANTES de finalizar: finish() invalida o histórico.
    // Dentro do runAction: se a rede falhar, o aluno vê a mensagem e a sessão continua aberta.
    List<WorkoutSession>? history;
    Map<int, String>? names;
    final loaded = await runAction(context, () async {
      history = await ref.read(historyProvider.future);
      names = await ref.read(exerciseNamesProvider.future);
    });
    if (!loaded || !mounted) return;
    WorkoutSession? finished;
    final ok = await runAction(context, () async {
      finished = await ref.read(executionProvider(_workoutId).notifier).finish();
    });
    if (!ok || finished == null || !mounted) return;

    ref.read(completedWorkoutProvider.notifier).set(WorkoutCompletion.compute(
          session: finished!,
          finishedAt: finished!.finishedAt!,
          plannedSets: planned,
          history: history!,
          exerciseNames: names!,
        ));
    context.go('/workouts/$_workoutId/done');
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(workoutPlanProvider(_workoutId));
    final execution = ref.watch(executionProvider(_workoutId));
    final name = ref.watch(myWorkoutsProvider).value?.where((w) => w.id == _workoutId).firstOrNull?.name;
    final rest = _rest;

    return Scaffold(
      body: rest != null
          ? RestView(plan: rest, onFinished: () => setState(() => _rest = null))
          : SafeArea(
              child: plan.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    ErrorRetry(error: error, onRetry: () => ref.invalidate(workoutPlanProvider(_workoutId))),
                data: (rows) => execution.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      ErrorRetry(error: error, onRetry: () => ref.invalidate(executionProvider(_workoutId))),
                  data: (session) => session == null
                      ? _NotStarted(workoutId: _workoutId, name: name)
                      : _InProgress(
                          name: name,
                          rows: rows,
                          session: session,
                          activeRow: rows.isEmpty ? null : _activeRow(rows, session),
                          onPick: (id) => setState(() => _selectedItemId = id),
                          onRegister: (row) => _register(row, session),
                          onEdit: (row, performance) => _edit(row, session, performance),
                          onFinish: () => _finish(rows, session),
                        ),
                ),
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, this.startedAt});

  final String? name;
  final DateTime? startedAt;

  @override
  Widget build(BuildContext context) {
    final parts = splitWorkoutName(name ?? 'Treino');
    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleIconButton(
            icon: LucideIcons.arrowLeft,
            tooltip: 'Voltar',
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          Expanded(
            child: Column(
              children: [
                if (parts.tag != null) LabelText(parts.tag!),
                Text(parts.title.toUpperCase(),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.display(22, weight: FontWeight.w600)),
              ],
            ),
          ),
          if (startedAt != null) ElapsedClock(startedAt: startedAt!) else const SizedBox(width: 44),
        ],
      ),
    );
  }
}

/// Sessão não iniciada (ou já finalizada): oferece iniciar. O fluxo normal inicia pelo
/// botão do detalhe do treino; este é só o caminho de segurança.
class _NotStarted extends ConsumerWidget {
  const _NotStarted({required this.workoutId, required this.name});

  final int workoutId;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _Header(name: name),
        const Expanded(
          child: EmptyState(icon: LucideIcons.play, message: 'Treino ainda não iniciado.'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 16),
          child: PillButton(
            key: const Key('start-workout'),
            label: 'Iniciar treino',
            icon: LucideIcons.play,
            onPressed: () => runAction(context, () => ref.read(executionProvider(workoutId).notifier).start()),
          ),
        ),
      ],
    );
  }
}

class _InProgress extends StatelessWidget {
  const _InProgress({
    required this.name,
    required this.rows,
    required this.session,
    required this.activeRow,
    required this.onPick,
    required this.onRegister,
    required this.onEdit,
    required this.onFinish,
  });

  final String? name;
  final List<PlanRow> rows;
  final WorkoutSession session;
  final PlanRow? activeRow;
  final ValueChanged<int> onPick;
  final ValueChanged<PlanRow> onRegister;
  final void Function(PlanRow, Performance) onEdit;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final planned = rows.fold<int>(0, (sum, r) => sum + r.item.sets);
    // séries acima do planejado (extras) não passam de 100%
    final done = rows.fold<int>(0, (sum, r) => sum + session.setsOf(r.item.id).length.clamp(0, r.item.sets));
    final progress = planned == 0 ? 0.0 : done / planned;
    final allDone = planned > 0 && done >= planned;

    return Column(
      children: [
        _Header(name: name, startedAt: session.startedAt),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(kScreenPadding, 16, kScreenPadding, 16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$done de $planned séries', key: const Key('workout-progress'), style: AppText.body(weight: FontWeight.w600)),
                  Text('${(progress * 100).round()}%',
                      style: AppText.body(weight: FontWeight.w500, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Progresso do treino',
                value: '${(progress * 100).round()}%',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.overlay,
                    color: AppColors.volt,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < rows.length; i++)
                if (rows[i] == activeRow)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ActiveExerciseCard(
                      number: i + 1,
                      row: rows[i],
                      sets: session.setsOf(rows[i].item.id),
                      onRegister: () => onRegister(rows[i]),
                      onEditSet: (performance) => onEdit(rows[i], performance),
                    ),
                  )
                else
                  CompactExerciseCard(
                    row: rows[i],
                    doneSets: session.setsOf(rows[i].item.id).length,
                    onTap: () => onPick(rows[i].item.id),
                  ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 16),
          // em destaque (volt) quando tudo foi feito; antes disso é secundário e pede confirmação
          child: PillButton(
            key: const Key('finish-workout'),
            label: 'Finalizar treino',
            icon: LucideIcons.check,
            height: 50,
            expand: false,
            style: allDone ? PillStyle.volt : PillStyle.ghost,
            onPressed: onFinish,
          ),
        ),
      ],
    );
  }
}
