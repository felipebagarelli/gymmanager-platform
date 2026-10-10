import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../workouts/domain/workout.dart';
import '../domain/workout_session.dart';

String _target(PlanItem item) {
  final parts = <String>['Meta ${item.sets} × ${item.reps}'];
  if (item.targetLoad != null) parts.add(formatLoad(item.targetLoad));
  if (item.restSeconds != null) parts.add('descanso ${item.restSeconds}s');
  return parts.join(' · ');
}

/// Exercício em andamento: expandido, com uma linha por série (feita / atual / futura).
class ActiveExerciseCard extends StatelessWidget {
  const ActiveExerciseCard({
    super.key,
    required this.number,
    required this.row,
    required this.sets,
    required this.onRegister,
    required this.onEditSet,
  });

  final int number;
  final PlanRow row;
  final List<Performance> sets;

  /// Abre o registro da próxima série.
  final VoidCallback onRegister;
  final ValueChanged<Performance> onEditSet;

  @override
  Widget build(BuildContext context) {
    final item = row.item;
    final group = row.muscleGroup;
    final color = muscleGroupColor(group);
    // séries extras (acima do planejado) continuam aparecendo como feitas
    final rowCount = item.sets > sets.length ? item.sets : sets.length;
    final complete = sets.length >= item.sets;
    final notes = item.notes;

    return Container(
      key: Key('active-${item.id}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.volt, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabelText('Exercício $number${group == null ? '' : ' · $group'}', color: color),
                    const SizedBox(height: 4),
                    Text(row.exerciseName.toUpperCase(), style: AppText.display(32).copyWith(letterSpacing: 0.6)),
                  ],
                ),
              ),
              TagChip('${sets.length}/${item.sets}', key: Key('progress-${item.id}')),
            ],
          ),
          const SizedBox(height: 10),
          Text(_target(item), style: AppText.body(size: 13.5, weight: FontWeight.w500, color: AppColors.textSecondary)),
          if (notes != null && notes.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(notes, style: AppText.body(size: 12.5, color: AppColors.textMuted))),
                ],
              ),
            ),
          const SizedBox(height: 12),
          for (var k = 0; k < rowCount; k++)
            if (k < sets.length)
              _DoneRow(performance: sets[k], onTap: () => onEditSet(sets[k]))
            else if (k == sets.length)
              _CurrentRow(number: k + 1, item: item, onRegister: onRegister)
            else
              _LaterRow(number: k + 1, item: item),
          if (complete)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('add-set-${item.id}'),
                onPressed: onRegister,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Série extra'),
              ),
            ),
        ],
      ),
    );
  }
}

class _SetRowShell extends StatelessWidget {
  const _SetRowShell({required this.child, this.highlight = false, this.dim = false, this.onTap});

  final Widget child;
  final bool highlight;
  final bool dim;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: dim ? 0.5 : 1,
        child: Material(
          color: highlight ? AppColors.mix(AppColors.volt, 0.07, AppColors.elevated) : AppColors.elevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: highlight ? const BorderSide(color: AppColors.volt) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.child, this.done = false});

  final Widget child;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: done ? AppColors.volt : AppColors.overlay, shape: BoxShape.circle),
      child: child,
    );
  }
}

class _DoneRow extends StatelessWidget {
  const _DoneRow({required this.performance, required this.onTap});

  final Performance performance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effort = performance.effort;
    return Semantics(
      button: true,
      label: 'Série ${performance.setNumber} feita, toque para editar',
      excludeSemantics: true,
      child: _SetRowShell(
        onTap: onTap,
        child: Row(
          key: Key('set-${performance.id}'),
          children: [
            const _Badge(done: true, child: Icon(LucideIcons.check, size: 16, color: AppColors.onVolt)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${performance.reps} reps × ${performance.loadKg == null ? '—' : '${formatNumber(performance.loadKg!)} kg'}',
                style: AppText.body(weight: FontWeight.w600),
              ),
            ),
            TagChip(effort == null ? 'Feita' : '${effort.label} · feita'),
          ],
        ),
      ),
    );
  }
}

class _CurrentRow extends StatelessWidget {
  const _CurrentRow({required this.number, required this.item, required this.onRegister});

  final int number;
  final PlanItem item;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final load = item.targetLoad == null ? '' : ' × ${formatLoad(item.targetLoad)}';
    return _SetRowShell(
      highlight: true,
      child: Row(
        children: [
          _Badge(child: Text('$number', style: AppText.display(16))),
          const SizedBox(width: 12),
          Expanded(child: Text('Meta ${item.reps}$load', style: AppText.body(weight: FontWeight.w600))),
          PillButton(
            key: Key('add-set-${item.id}'),
            label: 'Registrar',
            height: 38,
            expand: false,
            onPressed: onRegister,
          ),
        ],
      ),
    );
  }
}

class _LaterRow extends StatelessWidget {
  const _LaterRow({required this.number, required this.item});

  final int number;
  final PlanItem item;

  @override
  Widget build(BuildContext context) {
    final load = item.targetLoad == null ? '' : ' × ${formatLoad(item.targetLoad)}';
    return _SetRowShell(
      dim: true,
      child: Row(
        children: [
          _Badge(child: Text('$number', style: AppText.display(16))),
          const SizedBox(width: 12),
          Expanded(child: Text('Meta ${item.reps}$load', style: AppText.body(color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}

/// Exercício que não está em foco: card compacto com anel de progresso. Toque para focar.
class CompactExerciseCard extends StatelessWidget {
  const CompactExerciseCard({super.key, required this.row, required this.doneSets, required this.onTap});

  final PlanRow row;
  final int doneSets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = row.item;
    final complete = doneSets >= item.sets;
    final group = row.muscleGroup;
    final ringColor = complete ? AppColors.volt : muscleGroupColor(group);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        key: Key('compact-${item.id}'),
        radius: 18,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          children: [
            ProgressRing(
              value: item.sets == 0 ? 0 : doneSets / item.sets,
              color: ringColor,
              semanticsLabel: row.exerciseName,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.exerciseName, style: AppText.body(size: 16, weight: FontWeight.w600)),
                  Text(
                    // "Peito · 1/3": o grupo vem sempre em texto, a cor do anel é só reforço
                    [if (group != null && group.trim().isNotEmpty) group, '$doneSets/${item.sets}'].join(' · '),
                    key: Key('progress-${item.id}'),
                    style: AppText.body(size: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(complete ? LucideIcons.check : LucideIcons.chevronRight,
                size: 20, color: complete ? AppColors.volt : AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
