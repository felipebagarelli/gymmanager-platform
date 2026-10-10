import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../workouts/application/workout_providers.dart';
import '../domain/history_stats.dart';
import '../domain/workout_session.dart';

/// Abre o detalhe de uma sessão do histórico (séries por exercício).
Future<void> showSessionDetail(BuildContext context, {required WorkoutSession session, required String workoutName}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.elevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => SessionDetailSheet(session: session, workoutName: workoutName),
  );
}

class SessionDetailSheet extends ConsumerWidget {
  const SessionDetailSheet({super.key, required this.session, required this.workoutName});

  final WorkoutSession session;
  final String workoutName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(workoutPlanProvider(session.workoutId)).value ?? const [];
    final names = {for (final row in plan) row.item.id: row.exerciseName};
    // exercícios na ordem do plano; séries de itens que saíram do plano vão num grupo "Exercício"
    final order = [for (final row in plan) row.item.id];
    final byItem = <int, List<Performance>>{};
    for (final p in session.performances) {
      (byItem[p.workoutExerciseId] ??= []).add(p);
    }
    final itemIds = [
      ...order.where(byItem.containsKey),
      ...byItem.keys.where((id) => !order.contains(id)),
    ];
    final volume = sessionVolume(session);
    final sets = session.performances.length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        key: const Key('session-detail'),
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          // a alça de arrastar vem do tema (bottomSheetTheme)
          Text(workoutName.toUpperCase(), style: AppText.display(32)),
          const SizedBox(height: 2),
          Text(formatDateTime(session.startedAt), style: AppText.body(size: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _Stat(label: 'Tempo', value: durationLabel(session))),
              const SizedBox(width: 10),
              Expanded(child: _Stat(label: 'Volume', value: volume > 0 ? formatVolume(volume) : '—')),
              const SizedBox(width: 10),
              Expanded(child: _Stat(label: 'Séries', value: '$sets')),
            ],
          ),
          const SizedBox(height: 20),
          if (itemIds.isEmpty)
            Text('Nenhuma série registrada.', style: AppText.body(color: AppColors.textMuted))
          else
            for (final id in itemIds) ...[
              LabelText(names[id] ?? 'Exercício', color: AppColors.volt),
              const SizedBox(height: 8),
              for (final p in (byItem[id]!..sort((a, b) => a.setNumber.compareTo(b.setNumber)))) _SetRow(performance: p),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: AppText.display(26))),
          const SizedBox(height: 2),
          LabelText(label, size: 10),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.performance});

  final Performance performance;

  @override
  Widget build(BuildContext context) {
    final p = performance;
    final load = p.loadKg == null ? 'sem carga' : formatLoad(p.loadKg);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: Text('${p.setNumber}', style: AppText.display(15, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('${p.reps} reps × $load', style: AppText.body(size: 15, weight: FontWeight.w500))),
          if (p.effort != null) TagChip(p.effort!.label),
        ],
      ),
    );
  }
}
