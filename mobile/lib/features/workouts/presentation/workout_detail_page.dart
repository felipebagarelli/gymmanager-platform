import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../../sessions/application/session_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../application/workout_providers.dart';
import '../domain/plan_stats.dart';
import '../domain/workout_name.dart';
import 'muscle_focus.dart';
import 'plan_summary.dart';

/// Detalhe do treino (tela de fluxo: sem tab bar). Termina no botão fixo "Iniciar treino".
class WorkoutDetailPage extends ConsumerWidget {
  const WorkoutDetailPage({super.key, required this.workoutId});

  final int workoutId;

  /// Inicia a sessão (se ainda não houver uma em andamento) e abre a execução.
  Future<void> _start(BuildContext context, WidgetRef ref, bool hasOpenSession) async {
    final ok = hasOpenSession ||
        await runAction(context, () => ref.read(executionProvider(workoutId).notifier).start());
    if (ok && context.mounted) context.push('/workouts/$workoutId/run');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(workoutPlanProvider(workoutId));
    final workout = ref.watch(myWorkoutsProvider).value?.where((w) => w.id == workoutId).firstOrNull;
    final name = workout?.name;
    // treino montado pelo próprio aluno sem personal: ele pode editar
    final ownWorkout = workout != null && workout.ownedByStudent && ref.watch(currentStudentProvider)?.hasTrainer == false;
    final execution = ref.watch(executionProvider(workoutId));
    final hasOpenSession = execution.value != null;
    // carregando (ou recarregando, caso em que o valor antigo pode estar desatualizado) não dá para saber
    // se já existe sessão aberta: iniciar de novo daria 409
    final checkingSession = execution.isLoading;
    final parts = splitWorkoutName(name ?? 'Treino');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 0),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: LucideIcons.arrowLeft,
                    tooltip: 'Voltar',
                    onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                  ),
                  const Spacer(),
                  if (ownWorkout)
                    CircleIconButton(
                      key: const Key('edit-own-workout'),
                      icon: LucideIcons.pencil,
                      tooltip: 'Editar treino',
                      onPressed: () => context.push('/my-workouts/$workoutId/edit'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: plan.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    ErrorRetry(error: error, onRetry: () => ref.invalidate(workoutPlanProvider(workoutId))),
                data: (rows) {
                  if (rows.isEmpty) {
                    return const EmptyState(
                      icon: LucideIcons.listChecks,
                      message: 'Este treino ainda não tem exercícios.',
                    );
                  }
                  final stats = PlanStats.from(rows);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(kScreenPadding, 16, kScreenPadding, 24),
                    children: [
                      if (parts.tag != null) LabelText(parts.tag!, color: AppColors.volt, size: 13),
                      const SizedBox(height: 4),
                      Text(
                        parts.title.toUpperCase(),
                        key: const Key('detail-title'),
                        style: AppText.display(parts.title.length <= 12 ? 64 : 44, weight: FontWeight.w800)
                            .copyWith(height: 0.95),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(child: _Stat(value: '${stats.exercises}', label: 'Exercícios')),
                          const SizedBox(width: 10),
                          Expanded(child: _Stat(value: '${stats.sets}', label: 'Séries')),
                          const SizedBox(width: 10),
                          // estimativa (ver PlanStats): por isso o "~"
                          Expanded(child: _Stat(value: '~${stats.estimatedMinutes}′', label: 'Duração')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      MuscleFocusCard(focus: stats.focus),
                      const SizedBox(height: 22),
                      const SectionTitle('Exercícios'),
                      const SizedBox(height: 10),
                      for (var i = 0; i < rows.length; i++) ExerciseTile(number: i + 1, row: rows[i]),
                    ],
                  );
                },
              ),
            ),
            // botão fixo no rodapé, com degradê para o conteúdo "sumir" atrás dele
            Container(
              padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x000A0C0F), AppColors.bg],
                  stops: [0, 0.35],
                ),
              ),
              child: PillButton(
                key: const Key('open-execution'),
                label: hasOpenSession ? 'Continuar treino' : 'Iniciar treino',
                icon: LucideIcons.play,
                onPressed: (plan.value?.isNotEmpty ?? false) && !checkingSession
                    ? () => _start(context, ref, hasOpenSession)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppText.display(36))),
          const SizedBox(height: 2),
          LabelText(label),
        ],
      ),
    );
  }
}
