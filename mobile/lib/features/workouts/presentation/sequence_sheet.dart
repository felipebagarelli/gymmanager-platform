import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/pill_button.dart';
import '../domain/routine.dart';
import '../domain/workout.dart';

/// O que a pessoa escolheu na folha da sequência.
class SequenceChoice {
  const SequenceChoice({this.workoutIds = const [], this.useWeekdays = false, this.applyToOthers = false});

  /// Ordem da sequência (vazia quando [useWeekdays]).
  final List<int> workoutIds;

  /// Voltar ao modo dias da semana.
  final bool useWeekdays;

  /// O personal quer copiar a sequência para outros alunos.
  final bool applyToOthers;
}

/// Monta a sequência (AB, ABC...): marca os treinos que entram e arrasta para a ordem.
/// [allowApplyToOthers]: o personal pode salvar e copiar para outros alunos.
Future<SequenceChoice?> showSequenceSheet(BuildContext context,
    {required List<Workout> workouts, required Routine current, bool allowApplyToOthers = false}) {
  return showModalBottomSheet<SequenceChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.elevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => _SequenceSheet(workouts: workouts, current: current, allowApplyToOthers: allowApplyToOthers),
  );
}

class _SequenceSheet extends StatefulWidget {
  const _SequenceSheet({required this.workouts, required this.current, required this.allowApplyToOthers});

  final List<Workout> workouts;
  final Routine current;
  final bool allowApplyToOthers;

  @override
  State<_SequenceSheet> createState() => _SequenceSheetState();
}

class _SequenceSheetState extends State<_SequenceSheet> {
  late final List<Workout> _order;
  late final Set<int> _included;

  @override
  void initState() {
    super.initState();
    // os que já estão na sequência primeiro, na ordem dela; depois os demais
    final inSequence = {for (final i in widget.current.sequence) i.workoutId: i.order};
    _order = [...widget.workouts]
      ..sort((a, b) => (inSequence[a.id] ?? 999).compareTo(inSequence[b.id] ?? 999));
    _included = widget.current.rotation ? inSequence.keys.toSet() : {for (final w in widget.workouts) w.id};
  }

  List<int> get _chosen => [for (final w in _order) if (_included.contains(w.id)) w.id];

  @override
  Widget build(BuildContext context) {
    final valid = _chosen.length >= 2;
    var position = 0;
    final positions = {for (final w in _order) if (_included.contains(w.id)) w.id: ++position};
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        key: const Key('sequence-sheet'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SEQUÊNCIA DE TREINOS', style: AppText.display(26)),
                Text(
                  'O próximo treino é sempre o seguinte ao último feito, não importa o dia (bom para quem treina dia sim, dia não). '
                  'Marque os treinos e arraste para a ordem.',
                  style: AppText.body(size: 13.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              onReorderItem: (from, to) => setState(() => _order.insert(to, _order.removeAt(from))),
              children: [
                for (var i = 0; i < _order.length; i++)
                  ListTile(
                    key: ValueKey(_order[i].id),
                    leading: Checkbox(
                      key: Key('seq-check-${_order[i].id}'),
                      value: _included.contains(_order[i].id),
                      activeColor: AppColors.volt,
                      checkColor: AppColors.onVolt,
                      onChanged: (on) => setState(() => on == true ? _included.add(_order[i].id) : _included.remove(_order[i].id)),
                    ),
                    title: Text(_order[i].name, style: AppText.body(size: 15, weight: FontWeight.w600)),
                    subtitle: positions[_order[i].id] == null
                        ? null
                        : Text('${positions[_order[i].id]}º', style: AppText.body(size: 12.5, color: AppColors.volt)),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(LucideIcons.gripVertical, size: 20, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PillButton(
                    key: const Key('save-sequence'),
                    label: valid ? 'Usar esta sequência' : 'Marque 2 ou mais treinos',
                    onPressed: valid ? () => Navigator.of(context).pop(SequenceChoice(workoutIds: _chosen)) : null,
                  ),
                  if (widget.allowApplyToOthers) ...[
                    const SizedBox(height: 8),
                    PillButton(
                      key: const Key('save-sequence-others'),
                      label: 'Usar e copiar para outros alunos',
                      style: PillStyle.ghost,
                      height: 46,
                      onPressed: valid
                          ? () => Navigator.of(context).pop(SequenceChoice(workoutIds: _chosen, applyToOthers: true))
                          : null,
                    ),
                  ],
                  if (widget.current.rotation)
                    TextButton(
                      key: const Key('use-weekdays'),
                      onPressed: () => Navigator.of(context).pop(const SequenceChoice(useWeekdays: true)),
                      child: const Text('Voltar para os dias da semana'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
