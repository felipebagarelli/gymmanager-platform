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
import '../../auth/application/auth_controller.dart';
import '../../billing/presentation/overdue_view.dart';
import '../../../core/widgets/pill_button.dart';
import '../../home/application/home_tab_provider.dart';
import '../../trainer/workouts/presentation/trainer_workouts_page.dart';
import '../../sessions/application/session_providers.dart';
import '../../sessions/domain/training_stats.dart';
import '../application/workout_providers.dart';
import '../domain/workout.dart';
import '../../../core/providers.dart';
import 'today_reminder_banner.dart';
import 'weekdays.dart';
import 'week_card.dart';
import 'workout_hero.dart';

/// Aba "Treinos": saudação, semana, lembrete do dia, treino sugerido e próximos treinos.
class MyWorkoutsPage extends ConsumerWidget {
  const MyWorkoutsPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(historyProvider);
    ref.invalidate(myWorkoutsProvider);
    await ref.read(myWorkoutsProvider.future); // aguarda para o indicador de refresh sumir
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(myWorkoutsProvider);
    // sem personal: o aluno monta os próprios treinos
    final independent = ref.watch(currentStudentProvider)?.hasTrainer == false;

    return SafeArea(
      bottom: false,
      child: workouts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => isPaymentRequired(error)
            ? const OverdueView()
            : ErrorRetry(error: error, onRetry: () => ref.invalidate(myWorkoutsProvider)),
        data: (items) => RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 24),
            children: [
              const _Header(),
              const SizedBox(height: 16),
              if (items.isEmpty && independent)
                const _BuildFirstWorkout()
              else if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: EmptyState(
                    icon: LucideIcons.dumbbell,
                    message: 'Você ainda não tem treinos.\nSeu personal vai atribuir um em breve.',
                  ),
                )
              else ...[
                _Content(workouts: items),
                if (independent) ...[
                  const SizedBox(height: 14),
                  PillButton(
                    key: const Key('own-week'),
                    label: 'Organizar minha semana',
                    icon: LucideIcons.calendarDays,
                    style: PillStyle.ghost,
                    height: 46,
                    onPressed: () => _editOwnWeek(context, ref, items),
                  ),
                  const SizedBox(height: 8),
                  PillButton(
                    key: const Key('ai-workout'),
                    label: 'Pedir treino à IA',
                    icon: LucideIcons.sparkles,
                    style: PillStyle.ghost,
                    height: 46,
                    onPressed: () => context.push('/ai-workout'),
                  ),
                  const SizedBox(height: 8),
                  PillButton(
                    key: const Key('new-own-workout'),
                    label: 'Montar novo treino',
                    icon: LucideIcons.plus,
                    style: PillStyle.ghost,
                    height: 46,
                    onPressed: () => createWorkoutFlow(context, ref, editorPath: studentEditorPath),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Aluno sem personal: escolhe em que dias faz cada treino que montou.
Future<void> _editOwnWeek(BuildContext context, WidgetRef ref, List<Workout> workouts) async {
  final studentId = ref.read(currentStudentProvider)?.id;
  if (studentId == null) return;
  final days = await showWeekScheduleSheet(context, workouts: workouts);
  if (days == null || !context.mounted) return;
  final ok = await runAction(context, () => ref.read(workoutRepositoryProvider).setSchedule(studentId, days));
  if (ok) ref.invalidate(myWorkoutsProvider);
}

/// Aluno sem personal e sem treinos: convite para montar o primeiro.
class _BuildFirstWorkout extends ConsumerWidget {
  const _BuildFirstWorkout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Icon(LucideIcons.dumbbell, size: 48, color: AppColors.volt),
          const SizedBox(height: 12),
          Text('MONTE SEU PRIMEIRO TREINO', textAlign: TextAlign.center, style: AppText.display(28)),
          const SizedBox(height: 6),
          Text(
            'Escolha os exercícios do catálogo, séries e repetições. Depois é só registrar cada treino aqui.',
            textAlign: TextAlign.center,
            style: AppText.body(size: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          PillButton(
            key: const Key('ai-first-workout'),
            label: 'Montar com a IA',
            icon: LucideIcons.sparkles,
            onPressed: () => context.push('/ai-workout'),
          ),
          const SizedBox(height: 8),
          PillButton(
            key: const Key('build-first-workout'),
            label: 'Montar eu mesmo',
            icon: LucideIcons.plus,
            style: PillStyle.ghost,
            height: 46,
            onPressed: () => createWorkoutFlow(context, ref, editorPath: studentEditorPath),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentStudentProvider)?.name ?? '';
    final firstName = name.trim().split(RegExp(r'\s+')).first;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LabelText(formatLongDate(DateTime.now()), size: 12),
              const SizedBox(height: 4),
              Text(
                firstName.isEmpty ? 'BORA!' : 'BORA, ${firstName.toUpperCase()}',
                key: const Key('greeting'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(36).copyWith(letterSpacing: 0.7),
              ),
            ],
          ),
        ),
        // o avatar leva ao perfil (o sino de notificações do protótipo ainda não existe no app)
        Semantics(
          button: true,
          label: 'Abrir perfil',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => ref.read(homeTabProvider.notifier).select(HomeTab.profile),
            child: InitialsAvatar(name: name),
          ),
        ),
      ],
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.workouts});

  final List<Workout> workouts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(trainingStatsProvider);
    final history = ref.watch(historyProvider).value ?? const [];
    final goal = ref.watch(currentStudentProvider)?.weeklyGoal;

    final todaySession = stats?.todaySession;
    final today = ref.watch(clockProvider)().weekday;
    // com dias marcados, o cartão segue a semana; sem dias, sugere pelo histórico (o que faz mais tempo)
    final scheduled = workouts.any((w) => w.weekdays.isNotEmpty);
    final forToday = [for (final w in workouts) if (w.weekdays.contains(today)) w];
    final restDay = scheduled && forToday.isEmpty;
    final candidates = forToday.isNotEmpty ? forToday : workouts;
    final suggestedId = suggestedWorkoutId([for (final w in candidates) w.id], history);
    var hero = candidates.where((w) => w.id == suggestedId).firstOrNull ?? candidates.first;
    var heroLabel = 'TREINO DE HOJE';
    if (restDay) {
      // descanso hoje: mostra o próximo treino da semana
      final next = [for (final w in workouts) if (w.weekdays.isNotEmpty) w]
        ..sort((a, b) => daysUntilNext(a.weekdays, today)!.compareTo(daysUntilNext(b.weekdays, today)!));
      hero = next.first;
      final inDays = daysUntilNext(hero.weekdays, today)!;
      heroLabel = 'PRÓXIMO · ${weekdayLong[((today - 1 + inDays) % 7) + 1]!.toUpperCase()}';
    }
    final doneWorkout = todaySession == null
        ? null
        : workouts.where((w) => w.id == todaySession.workoutId).firstOrNull;
    final highlighted = doneWorkout ?? hero;
    // próximos: na ordem da semana a partir de hoje; os sem dia, no fim
    final others = [for (final w in workouts) if (w.id != highlighted.id) w]
      ..sort((a, b) => (daysUntilNext(a.weekdays, today) ?? 99).compareTo(daysUntilNext(b.weekdays, today) ?? 99));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stats != null) ...[WeekCard(stats: stats, weeklyGoal: goal), const SizedBox(height: 14)],
        TodayReminderBanner(restDay: restDay),
        const SizedBox(height: 14),
        if (doneWorkout != null && todaySession != null)
          TodayDoneCard(workoutName: doneWorkout.name, session: todaySession)
        else
          WorkoutHero(
            label: heroLabel,
            name: hero.name,
            stats: ref.watch(planStatsProvider(hero.id)).value,
            onStart: () => context.push('/workouts/${hero.id}'),
          ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 22),
          const SectionTitle('Próximos treinos'),
          const SizedBox(height: 10),
          for (final workout in others) _WorkoutRow(workout: workout),
        ],
      ],
    );
  }
}

class _WorkoutRow extends ConsumerWidget {
  const _WorkoutRow({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(planStatsProvider(workout.id)).value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        key: Key('workout-${workout.id}'),
        padding: const EdgeInsets.all(12),
        radius: 16,
        onTap: () => context.push('/workouts/${workout.id}'),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(12)),
              child: const Icon(LucideIcons.dumbbell, size: 22, color: AppColors.volt),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workout.name, style: AppText.body(size: 16, weight: FontWeight.w600)),
                  if (workout.weekdays.isNotEmpty)
                    Text(formatWeekdays(workout.weekdays),
                        key: Key('workout-days-${workout.id}'),
                        style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.volt)),
                  if (stats != null)
                    Text(describePlan(stats), style: AppText.body(size: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
