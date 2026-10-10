import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../workouts/application/workout_providers.dart';
import '../application/session_providers.dart';
import '../domain/history_stats.dart';
import '../domain/training_stats.dart';
import '../domain/workout_session.dart';
import 'session_detail_sheet.dart';

const _weekLabels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

/// Aba "Sessões": calendário do mês com intensidade, números do mês e lista de sessões.
class SessionsTab extends ConsumerStatefulWidget {
  const SessionsTab({super.key});

  @override
  ConsumerState<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends ConsumerState<SessionsTab> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    return history.when(
      loading: () => const SkeletonList(),
      error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(historyProvider)),
      data: (sessions) {
        if (sessions.isEmpty) {
          return const EmptyState(icon: LucideIcons.history, message: 'Você ainda não executou nenhum treino.');
        }
        final now = ref.watch(clockProvider)();
        final thisMonth = DateTime(now.year, now.month);
        final month = _month ?? thisMonth;
        final summary = MonthSummary.of(sessions, month);
        final streak = TrainingStats.from(sessions, now: now).streakWeeks;
        final inMonth = [
          for (final s in sessions)
            if (s.startedAt.toLocal().year == month.year && s.startedAt.toLocal().month == month.month) s,
        ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

        return RefreshIndicator(
          onRefresh: () async => ref.refresh(historyProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 24),
            children: [
              _CalendarCard(
                summary: summary,
                today: now,
                canGoForward: month.isBefore(thisMonth),
                onPrevious: () => setState(() => _month = DateTime(month.year, month.month - 1)),
                onNext: () => setState(() => _month = DateTime(month.year, month.month + 1)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Kpi(key: const Key('kpi-month-volume'), value: _volumeNumber(summary.volumeKg), unit: _volumeUnit(summary.volumeKg), label: 'Volume no mês')),
                  const SizedBox(width: 12),
                  Expanded(child: _Kpi(key: const Key('kpi-streak'), value: '$streak', label: streak == 1 ? 'Semana seguida' : 'Semanas seguidas')),
                ],
              ),
              const SizedBox(height: 20),
              const SectionTitle('Sessões'),
              const SizedBox(height: 10),
              if (inMonth.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Nenhum treino em ${formatMonthYear(month).toLowerCase()}.',
                        key: const Key('month-empty'), style: AppText.body(color: AppColors.textMuted)),
                  ),
                )
              else
                for (final session in inMonth) _SessionTile(session: session),
            ],
          ),
        );
      },
    );
  }
}

String _volumeNumber(double kg) => formatVolume(kg).split(' ').first;
String _volumeUnit(double kg) => formatVolume(kg).split(' ').last;

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.summary,
    required this.today,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final MonthSummary summary;
  final DateTime today;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final month = summary.month;
    final isCurrentMonth = today.year == month.year && today.month == month.month;
    final trainings = summary.sessionCount;

    return AppCard(
      key: const Key('calendar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ArrowButton(key: const Key('month-previous'), icon: LucideIcons.chevronLeft, label: 'Mês anterior', onPressed: onPrevious),
              Expanded(
                child: Column(
                  children: [
                    Text(formatMonthYear(month), key: const Key('month-title'), style: AppText.display(24, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(trainings == 1 ? '1 treino' : '$trainings treinos',
                        style: AppText.body(size: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              _ArrowButton(
                key: const Key('month-next'),
                icon: LucideIcons.chevronRight,
                label: 'Próximo mês',
                onPressed: canGoForward ? onNext : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final label in _weekLabels)
                Expanded(child: Center(child: Text(label, style: AppText.label(size: 11)))),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (var i = 0; i < summary.leadingBlanks; i++) const SizedBox.shrink(),
              for (var day = 1; day <= summary.daysInMonth; day++)
                _DayCell(
                  day: day,
                  level: summary.levels[day],
                  isToday: isCurrentMonth && day == today.day,
                  isFuture: isCurrentMonth && day > today.day,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const _Legend(),
        ],
      ),
    );
  }
}

Color _levelColor(int level) => switch (level) {
      1 => AppColors.mix(AppColors.volt, 0.30, AppColors.elevated),
      2 => AppColors.mix(AppColors.volt, 0.62, AppColors.elevated),
      3 => AppColors.volt,
      _ => AppColors.elevated,
    };

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.level, required this.isToday, required this.isFuture});

  final int day;
  final int? level;
  final bool isToday;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    final trained = level != null;
    final textColor = level == 3
        ? AppColors.onVolt
        : (isFuture ? AppColors.textMuted.withValues(alpha: 0.5) : (trained ? AppColors.textPrimary : AppColors.textSecondary));
    return Semantics(
      label: 'Dia $day${trained ? ', treino realizado' : ''}${isToday ? ', hoje' : ''}',
      excludeSemantics: true,
      child: Container(
        key: Key('day-$day'),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _levelColor(level ?? 0),
          borderRadius: BorderRadius.circular(10),
          border: isToday ? Border.all(color: AppColors.volt, width: 1.6) : null,
        ),
        child: Text('$day', style: AppText.body(size: 13, weight: trained ? FontWeight.w700 : FontWeight.w500, color: textColor)),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Menos', style: AppText.body(size: 12, color: AppColors.textMuted)),
        const SizedBox(width: 6),
        for (final level in [0, 1, 2, 3])
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: _levelColor(level), borderRadius: BorderRadius.circular(4)),
          ),
        const SizedBox(width: 2),
        Text('Mais', style: AppText.body(size: 12, color: AppColors.textMuted)),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: Icon(icon, size: 22, color: onPressed == null ? AppColors.textMuted.withValues(alpha: 0.4) : AppColors.textPrimary),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({super.key, required this.value, this.unit, required this.label});

  final String value;
  final String? unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppText.display(38)),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit!, style: AppText.display(18, color: AppColors.textSecondary, weight: FontWeight.w600)),
              ],
            ],
          ),
          const SizedBox(height: 2),
          LabelText(label),
        ],
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutName = ref.watch(myWorkoutsProvider).value?.where((w) => w.id == session.workoutId).firstOrNull?.name ??
        'Treino #${session.workoutId}';
    final date = session.startedAt.toLocal();
    final sets = session.performances.length;
    final details = [
      durationLabel(session),
      if (!session.isOpen || sets > 0) '$sets ${sets == 1 ? 'série' : 'séries'}',
      if (sessionVolume(session) > 0) formatVolume(sessionVolume(session)),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        key: Key('session-${session.id}'),
        radius: 18,
        padding: const EdgeInsets.all(12),
        onTap: () => showSessionDetail(context, session: session, workoutName: workoutName),
        child: Row(
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  Text('${date.day}', style: AppText.display(24)),
                  Text(formatShortMonth(date), style: AppText.label(size: 10)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workoutName, style: AppText.body(size: 16, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
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
