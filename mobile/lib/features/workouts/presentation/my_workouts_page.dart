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
import '../../home/application/home_tab_provider.dart';
import '../../sessions/application/session_providers.dart';
import '../../sessions/domain/training_stats.dart';
import '../application/workout_providers.dart';
import '../domain/workout.dart';
import 'today_reminder_banner.dart';
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
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: EmptyState(
                    icon: LucideIcons.dumbbell,
                    message: 'Você ainda não tem treinos.\nSeu personal vai atribuir um em breve.',
                  ),
                )
              else
                _Content(workouts: items),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authControllerProvider).value?.name ?? '';
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
    final goal = ref.watch(authControllerProvider).value?.weeklyGoal;

    final todaySession = stats?.todaySession;
    final suggestedId = suggestedWorkoutId([for (final w in workouts) w.id], history);
    final hero = workouts.where((w) => w.id == suggestedId).firstOrNull ?? workouts.first;
    final doneWorkout = todaySession == null
        ? null
        : workouts.where((w) => w.id == todaySession.workoutId).firstOrNull;
    final highlighted = doneWorkout ?? hero;
    final others = [for (final w in workouts) if (w.id != highlighted.id) w];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stats != null) ...[WeekCard(stats: stats, weeklyGoal: goal), const SizedBox(height: 14)],
        const TodayReminderBanner(),
        const SizedBox(height: 14),
        if (doneWorkout != null && todaySession != null)
          TodayDoneCard(workoutName: doneWorkout.name, session: todaySession)
        else
          WorkoutHero(
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
