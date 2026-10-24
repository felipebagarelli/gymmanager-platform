import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/async_widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../onboarding/domain/onboarding.dart';
import '../../../sessions/domain/history_stats.dart';
import '../../../sessions/domain/training_stats.dart';
import '../../../sessions/domain/workout_session.dart';
import '../../../sessions/presentation/session_detail_sheet.dart';
import '../../../workouts/domain/workout.dart';
import '../../../chat/application/chat_providers.dart';
import '../../messages/presentation/trainer_messages_page.dart';
import '../../workouts/presentation/workout_pickers.dart';
import '../application/students_providers.dart';
import '../domain/managed_student.dart';
import 'student_badges.dart';

/// Perfil de um aluno visto pelo personal: dados, números, treinos e sessões (com o "Como foi?").
class StudentDetailPage extends ConsumerWidget {
  const StudentDetailPage({super.key, required this.studentId});

  final int studentId;

  Future<void> _deactivate(BuildContext context, WidgetRef ref, ManagedStudent student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desativar aluno?'),
        content: Text(
          'O acompanhamento acaba: a mensalidade com você é cancelada, seus treinos saem da lista e o chat fecha. '
          '${student.name.split(' ').first} continua no app pelo plano grátis, com o histórico.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Voltar')),
          FilledButton(
            key: const Key('confirm-deactivate'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desativar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await runAction(context, () => ref.read(studentsRepositoryProvider).deactivate(student.id));
    if (ok) refreshStudent(ref, student.id);
  }

  Future<void> _reactivate(BuildContext context, WidgetRef ref, ManagedStudent student) async {
    final ok = await runAction(context, () => ref.read(studentsRepositoryProvider).reactivate(student.id));
    if (ok) refreshStudent(ref, student.id);
  }

  Future<void> _setPaused(BuildContext context, WidgetRef ref, ManagedStudent student, bool paused) async {
    if (paused) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pausar acompanhamento?'),
          content: Text(
            'Durante a pausa, o chat com ${student.name.split(' ').first} fica fechado e ele não assina planos novos. '
            'Os treinos e o histórico continuam.\n\n'
            'A mensalidade no Stripe não é pausada: se precisar, cancele ou ajuste a cobrança por lá.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Voltar')),
            FilledButton(
              key: const Key('confirm-pause'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Pausar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    final ok = await runAction(context, () => ref.read(studentsRepositoryProvider).setPaused(student.id, paused));
    if (ok) {
      refreshStudent(ref, student.id);
      // o chat abre ou fecha junto com a pausa
      ref.invalidate(trainerConversationsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = ref.watch(managedStudentProvider(studentId));
    final tuition = ref.watch(tuitionByStudentProvider).value?[studentId];

    return Scaffold(
      body: SafeArea(
        child: student.when(
          loading: () => const SkeletonList(heights: [56, 90, 90, 140, 140]),
          error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(managedStudentProvider(studentId))),
          data: (s) => ListView(
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
                  Row(
                    children: [
                      CircleIconButton(
                        key: const Key('message-student'),
                        icon: LucideIcons.messageSquare,
                        tooltip: 'Enviar mensagem',
                        onPressed: () => openConversationWith(context, ref, s.id),
                      ),
                      const SizedBox(width: 8),
                      CircleIconButton(
                        key: const Key('edit-student'),
                        icon: LucideIcons.pencil,
                        tooltip: 'Editar aluno',
                        onPressed: () => context.push('/trainer/students/${s.id}/edit'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  InitialsAvatar(name: s.name, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name.toUpperCase(),
                            key: const Key('student-name'), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.display(30)),
                        Text(s.email, style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              if (studentBadges(s, tuition).isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: studentBadges(s, tuition)),
              ],
              const SizedBox(height: 16),
              _Numbers(student: s),
              const SizedBox(height: 14),
              _Info(student: s),
              const SizedBox(height: 12),
              AppCard(
                key: const Key('open-progress'),
                radius: 18,
                padding: const EdgeInsets.all(14),
                onTap: () => context.push('/trainer/students/${s.id}/progress?tab=1'),
                child: Row(
                  children: [
                    const Icon(LucideIcons.trendingUp, size: 22, color: AppColors.volt),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Evolução', style: AppText.body(size: 15.5, weight: FontWeight.w600)),
                          Text('Cargas por exercício, volume semanal e recordes',
                              style: AppText.body(size: 13, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textMuted),
                  ],
                ),
              ),
              if (s.active) ...[
                const SizedBox(height: 12),
                _Health(studentId: s.id),
              ],
              const SizedBox(height: 20),
              _WorkoutsTitle(studentId: s.id, active: s.active),
              const SizedBox(height: 8),
              _Workouts(studentId: s.id),
              const SizedBox(height: 20),
              SectionTitle('Sessões recentes',
                  action: 'Calendário', onAction: () => context.push('/trainer/students/${s.id}/progress')),
              const SizedBox(height: 8),
              _Sessions(studentId: s.id),
              const SizedBox(height: 24),
              if (!s.active)
                PillButton(
                  key: const Key('reactivate-student'),
                  label: 'Reativar aluno',
                  icon: LucideIcons.userCheck,
                  height: 50,
                  onPressed: () => _reactivate(context, ref, s),
                )
              else ...[
                PillButton(
                  key: Key(s.paused ? 'resume-student' : 'pause-student'),
                  label: s.paused ? 'Retomar acompanhamento' : 'Pausar acompanhamento',
                  icon: s.paused ? LucideIcons.play : LucideIcons.pause,
                  style: s.paused ? PillStyle.volt : PillStyle.ghost,
                  height: 46,
                  onPressed: () => _setPaused(context, ref, s, !s.paused),
                ),
                const SizedBox(height: 10),
                PillButton(
                  key: const Key('deactivate-student'),
                  label: 'Desativar aluno',
                  icon: LucideIcons.userX,
                  style: PillStyle.ghost,
                  height: 46,
                  onPressed: () => _deactivate(context, ref, s),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Triagem de saúde e perfil de treino: só aparecem se o aluno autorizou.
class _Health extends ConsumerWidget {
  const _Health({required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(studentHealthProvider(studentId)).value;
    if (health == null) return const SizedBox.shrink();
    final profile = health.trainingProfile;
    final yes = [
      for (var i = 0; i < health.answers.length && i < screeningQuestions.length; i++)
        if (health.answers[i]) screeningQuestions[i],
    ];
    return AppCard(
      key: const Key('student-health'),
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.heartPulse, size: 20, color: AppColors.volt),
              const SizedBox(width: 10),
              Expanded(child: Text('Saúde', style: AppText.body(size: 15.5, weight: FontWeight.w600))),
              if (health.risk == true) const TagChip('Atenção'),
            ],
          ),
          const SizedBox(height: 6),
          if (!health.shared)
            Text('O aluno não autorizou mostrar a triagem. Ele pode liberar em Perfil.',
                key: const Key('health-not-shared'), style: AppText.body(size: 13, color: AppColors.textMuted))
          else ...[
            if (profile != null)
              Text(
                '${profile.goal.label} · ${profile.level.label} · ${profile.daysPerWeek}x/semana · ${profile.location.label}',
                style: AppText.body(size: 13.5, color: AppColors.textSecondary),
              ),
            if (health.answeredAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Triagem respondida em ${formatShortDate(health.answeredAt!)}',
                    style: AppText.body(size: 12.5, color: AppColors.textMuted)),
              ),
            const SizedBox(height: 6),
            if (health.answeredAt == null)
              Text('Triagem ainda não respondida.', style: AppText.body(size: 13, color: AppColors.textMuted))
            else if (yes.isEmpty)
              Text('Respondeu "não" a todas as perguntas.', style: AppText.body(size: 13.5))
            else
              for (final q in yes)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• Sim: $q', style: AppText.body(size: 13.5)),
                ),
          ],
        ],
      ),
    );
  }
}

/// Treinos feitos, semanas seguidas e a meta da semana.
class _Numbers extends ConsumerWidget {
  const _Numbers({required this.student});

  final ManagedStudent student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(studentSessionsProvider(student.id)).value;
    final now = ref.watch(clockProvider)();
    final stats = sessions == null ? null : TrainingStats.from(sessions, now: now);
    final goal = student.weeklyGoal;

    return Row(
      children: [
        Expanded(child: _Stat(key: const Key('stat-done'), value: sessions == null ? '—' : '${finishedSessions(sessions).length}', label: 'Treinos')),
        const SizedBox(width: 10),
        Expanded(child: _Stat(key: const Key('stat-streak'), value: stats == null ? '—' : '${stats.streakWeeks}', label: 'Semanas')),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            key: const Key('stat-week'),
            value: stats == null ? '—' : (goal == null ? '${stats.sessionsThisWeek}' : '${stats.sessionsThisWeek}/$goal'),
            label: goal == null ? 'Nesta semana' : 'Meta da semana',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: AppText.display(32))),
          LabelText(label, size: 10),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.student});

  final ManagedStudent student;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final rows = <(String, String)>[
      if (s.phone != null && s.phone!.trim().isNotEmpty) ('Telefone', s.phone!),
      if (s.birthDate != null) ('Nascimento', formatBirthDate(s.birthDate!)),
      if (s.goal != null && s.goal!.trim().isNotEmpty) ('Objetivo', s.goal!),
      if (s.height != null) ('Altura', '${formatNumber(s.height!)} m'),
      if (s.weight != null) ('Peso', '${formatNumber(s.weight!)} kg'),
      ('Meta semanal', s.weeklyGoal == null ? 'Sem meta' : '${s.weeklyGoal} treinos'),
    ];
    return AppCard(
      key: const Key('student-info'),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            LabelText(rows[i].$1),
            const SizedBox(height: 2),
            Text(rows[i].$2, style: AppText.body(size: 15.5, weight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}

/// Título "Treinos" com o atalho para atribuir um treino (só para aluno ativo).
class _WorkoutsTitle extends ConsumerWidget {
  const _WorkoutsTitle({required this.studentId, required this.active});

  final int studentId;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned = ref.watch(studentWorkoutsProvider(studentId)).value ?? const <Workout>[];
    return SectionTitle(
      'Treinos',
      action: active ? 'Atribuir' : null,
      onAction: () => showAssignWorkout(context, studentId: studentId, alreadyAssigned: {for (final w in assigned) w.id}),
    );
  }
}

class _Workouts extends ConsumerWidget {
  const _Workouts({required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(studentWorkoutsProvider(studentId));
    return workouts.when(
      loading: () => const SkeletonBox(height: 60),
      error: (error, _) => Text(messageOf(error), style: AppText.body(color: AppColors.textMuted)),
      data: (items) => items.isEmpty
          ? Text('Nenhum treino atribuído.', key: const Key('no-workouts'), style: AppText.body(color: AppColors.textMuted))
          : Column(
              children: [
                for (final Workout w in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      key: Key('student-workout-${w.id}'),
                      radius: 16,
                      padding: const EdgeInsets.all(12),
                      onTap: () => context.push('/trainer/workouts/${w.id}'),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.dumbbell, size: 20, color: AppColors.volt),
                          const SizedBox(width: 12),
                          Expanded(child: Text(w.name, style: AppText.body(size: 15.5, weight: FontWeight.w600))),
                          const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Sessions extends ConsumerWidget {
  const _Sessions({required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(studentSessionsProvider(studentId));
    final names = {for (final w in ref.watch(studentWorkoutsProvider(studentId)).value ?? const <Workout>[]) w.id: w.name};
    return sessions.when(
      loading: () => const SkeletonBox(height: 120),
      error: (error, _) => Text(messageOf(error), style: AppText.body(color: AppColors.textMuted)),
      data: (items) {
        if (items.isEmpty) {
          return Text('Ainda não há sessões registradas.', key: const Key('no-sessions'), style: AppText.body(color: AppColors.textMuted));
        }
        return Column(
          children: [
            for (final WorkoutSession session in items.take(10))
              _SessionRow(session: session, workoutName: names[session.workoutId] ?? 'Treino #${session.workoutId}'),
          ],
        );
      },
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.workoutName});

  final WorkoutSession session;
  final String workoutName;

  @override
  Widget build(BuildContext context) {
    final date = session.startedAt.toLocal();
    final sets = session.performances.length;
    final volume = sessionVolume(session);
    final details = [
      durationLabel(session),
      '$sets ${sets == 1 ? 'série' : 'séries'}',
      if (volume > 0) formatVolume(volume),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        key: Key('session-${session.id}'),
        radius: 16,
        padding: const EdgeInsets.all(12),
        onTap: () => showSessionDetail(context, session: session, workoutName: workoutName),
        child: Row(
          children: [
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Text('${date.day}', style: AppText.display(22)),
                  Text(formatShortMonth(date), style: AppText.label(size: 10)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workoutName, style: AppText.body(size: 15, weight: FontWeight.w600)),
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
