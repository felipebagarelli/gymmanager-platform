import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/async_widgets.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../workouts/domain/workout.dart';
import '../../../workouts/domain/workout_name.dart';
import '../application/trainer_workouts_providers.dart';
import 'workout_pickers.dart';
import 'workout_sheets.dart';

/// Cria um treino pelo nome e abre o editor para montar o plano.
Future<void> createWorkoutFlow(BuildContext context, WidgetRef ref) async {
  final name = await promptWorkoutName(context, title: 'Novo treino', action: 'Criar');
  if (name == null || !context.mounted) return;
  Workout? created;
  final ok = await runAction(context, () async {
    created = await ref.read(trainerWorkoutsRepositoryProvider).create(name);
  });
  if (!ok || created == null) return;
  ref.invalidate(trainerWorkoutsProvider);
  if (context.mounted) context.push('/trainer/workouts/${created!.id}');
}

/// Aba "Treinos" do personal: os treinos dele e o acesso à biblioteca de exercícios.
class TrainerWorkoutsPage extends ConsumerStatefulWidget {
  const TrainerWorkoutsPage({super.key});

  @override
  ConsumerState<TrainerWorkoutsPage> createState() => _TrainerWorkoutsPageState();
}

class _TrainerWorkoutsPageState extends ConsumerState<TrainerWorkoutsPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workouts = ref.watch(trainerWorkoutsProvider);

    return SafeArea(
      bottom: false,
      child: workouts.when(
        loading: () => const SkeletonList(heights: [56, 64, 80, 80, 80]),
        error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(trainerWorkoutsProvider)),
        data: (items) {
          final query = _search.text.trim().toLowerCase();
          final visible = [for (final w in items) if (query.isEmpty || w.name.toLowerCase().contains(query)) w];
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(trainerWorkoutsProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TREINOS', style: AppText.display(36).copyWith(letterSpacing: 0.7)),
                          Text(items.length == 1 ? '1 treino montado' : '${items.length} treinos montados',
                              key: const Key('workouts-count'), style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Novo treino',
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: const Key('new-workout'),
                        onTap: () => createWorkoutFlow(context, ref),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(gradient: AppColors.ctaGradient, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.plus, size: 24, color: AppColors.onVolt),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppCard(
                  key: const Key('open-library'),
                  radius: 18,
                  padding: const EdgeInsets.all(14),
                  onTap: () => context.push('/trainer/exercises'),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.library, size: 22, color: AppColors.volt),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Biblioteca de exercícios', style: AppText.body(size: 15.5, weight: FontWeight.w600)),
                            Text('Catálogo comum e os exercícios que você criou',
                                style: AppText.body(size: 13, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (items.length > 4) ...[
                  TextField(
                    key: const Key('workouts-search'),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: 'Buscar treino', prefixIcon: Icon(LucideIcons.search, size: 18)),
                  ),
                  const SizedBox(height: 12),
                ],
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: LucideIcons.dumbbell,
                      message: 'Nenhum treino ainda.\nToque em + para montar o primeiro.',
                    ),
                  )
                else if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Center(child: Text('Nenhum treino encontrado.', style: AppText.body(color: AppColors.textMuted))),
                  )
                else
                  for (final w in visible) _WorkoutTile(workout: w),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final name = splitWorkoutName(workout.name);
    final students = workout.studentCount ?? 0;
    final details = [
      exerciseCountLabel(workout.exerciseCount),
      students == 0 ? 'Nenhum aluno' : (students == 1 ? '1 aluno' : '$students alunos'),
    ].where((s) => s.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        key: Key('workout-${workout.id}'),
        radius: 18,
        padding: const EdgeInsets.all(14),
        onTap: () => context.push('/trainer/workouts/${workout.id}'),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(14)),
              child: const Icon(LucideIcons.dumbbell, size: 22, color: AppColors.volt),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.tag != null) LabelText(name.tag!, size: 10.5),
                  Text(name.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body(size: 16, weight: FontWeight.w600)),
                  Text(details, style: AppText.body(size: 13, color: AppColors.textMuted)),
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
