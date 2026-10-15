import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/pill_button.dart';
import '../domain/workout_draft.dart';

/// Pede o nome de um treino (novo ou renomear). Retorna null se o personal cancelar.
Future<String?> promptWorkoutName(BuildContext context, {String initial = '', required String title, required String action}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(initial: initial, title: title, action: action),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial, required this.title, required this.action});

  final String initial;
  final String title;
  final String action;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Dê um nome ao treino');
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('workout-name'),
        controller: _name,
        autofocus: true,
        maxLength: 120,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'Ex.: Treino A - Peito e tríceps',
          errorText: _error,
          counterText: '',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(key: const Key('workout-name-save'), onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}

/// Confirmação simples (excluir, retirar aluno...). Retorna true só se o personal confirmar.
Future<bool> confirmAction(BuildContext context,
    {required String title, required String message, required String action, Key? confirmKey}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Voltar')),
        FilledButton(key: confirmKey ?? const Key('confirm-action'), onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
      ],
    ),
  );
  return ok == true;
}

// ---------------------------------------------------------------- exercício (biblioteca)

/// Resultado do formulário de exercício: nome e grupo, ou um pedido para excluir.
class ExerciseFormResult {
  const ExerciseFormResult({this.name = '', this.muscleGroup = '', this.delete = false});

  final String name;
  final String muscleGroup;
  final bool delete;
}

/// Criar (sem [initialName]) ou editar um exercício do personal.
Future<ExerciseFormResult?> showExerciseForm(
  BuildContext context, {
  String? initialName,
  String? initialGroup,
  List<String> groups = defaultMuscleGroups,
}) {
  return showModalBottomSheet<ExerciseFormResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ExerciseForm(initialName: initialName, initialGroup: initialGroup, groups: groups),
  );
}

class _ExerciseForm extends StatefulWidget {
  const _ExerciseForm({required this.initialName, required this.initialGroup, required this.groups});

  final String? initialName;
  final String? initialGroup;
  final List<String> groups;

  @override
  State<_ExerciseForm> createState() => _ExerciseFormState();
}

class _ExerciseFormState extends State<_ExerciseForm> {
  late final _name = TextEditingController(text: widget.initialName ?? '');
  late final _group = TextEditingController(text: widget.initialGroup ?? '');
  final _errors = <String, String>{};

  bool get _editing => widget.initialName != null;

  @override
  void dispose() {
    _name.dispose();
    _group.dispose();
    super.dispose();
  }

  void _save() {
    setState(() {
      _errors.clear();
      if (_name.text.trim().isEmpty) _errors['name'] = 'Informe o nome do exercício';
      if (_group.text.trim().isEmpty) _errors['group'] = 'Escolha ou digite o grupo muscular';
    });
    if (_errors.isNotEmpty) return;
    Navigator.of(context).pop(ExerciseFormResult(name: _name.text.trim(), muscleGroup: _group.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_editing ? 'EDITAR EXERCÍCIO' : 'NOVO EXERCÍCIO', style: AppText.display(30)),
              const SizedBox(height: 14),
              TextField(
                key: const Key('exercise-name'),
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Nome', hintText: 'Ex.: Supino inclinado com halteres', errorText: _errors['name']),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('exercise-group'),
                controller: _group,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: 'Grupo muscular', errorText: _errors['group']),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final group in widget.groups)
                    ChoiceChip(
                      key: Key('group-$group'),
                      label: Text(group),
                      selected: _group.text.trim().toLowerCase() == group.toLowerCase(),
                      onSelected: (_) => setState(() => _group.text = group),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              PillButton(key: const Key('exercise-save'), label: _editing ? 'Salvar alterações' : 'Criar exercício', onPressed: _save),
              if (_editing)
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    key: const Key('exercise-delete'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () => Navigator.of(context).pop(const ExerciseFormResult(delete: true)),
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    label: const Text('Excluir exercício'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- exercício dentro do treino

/// Resultado do sheet de exercício no treino: os valores, ou um pedido para retirar do treino.
class PlanItemSheetResult {
  const PlanItemSheetResult({this.draft, this.remove = false});

  final PlanItemDraft? draft;
  final bool remove;
}

/// Séries, repetições, descanso, carga e observação de um exercício no treino.
Future<PlanItemSheetResult?> showPlanItemSheet(
  BuildContext context, {
  required String exerciseName,
  String? muscleGroup,
  required PlanItemDraft initial,
  bool editing = false,
}) {
  return showModalBottomSheet<PlanItemSheetResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PlanItemSheet(exerciseName: exerciseName, muscleGroup: muscleGroup, initial: initial, editing: editing),
  );
}

class _PlanItemSheet extends StatefulWidget {
  const _PlanItemSheet({required this.exerciseName, required this.muscleGroup, required this.initial, required this.editing});

  final String exerciseName;
  final String? muscleGroup;
  final PlanItemDraft initial;
  final bool editing;

  @override
  State<_PlanItemSheet> createState() => _PlanItemSheetState();
}

class _PlanItemSheetState extends State<_PlanItemSheet> {
  late int _sets = widget.initial.sets;
  late int _reps = widget.initial.reps;
  late int _rest = widget.initial.restSeconds ?? 60;
  late final _load = TextEditingController(
    text: widget.initial.targetLoad == null ? '' : formatNumber(widget.initial.targetLoad!),
  );
  late final _notes = TextEditingController(text: widget.initial.notes ?? '');
  String? _error;

  @override
  void dispose() {
    _load.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final loadText = _load.text.trim();
    final load = loadText.isEmpty ? null : parseDecimal(loadText);
    if (loadText.isNotEmpty && (load == null || load < 0)) return setState(() => _error = 'Carga inválida');
    Navigator.of(context).pop(PlanItemSheetResult(
      draft: PlanItemDraft(
        exerciseId: widget.initial.exerciseId,
        sets: _sets,
        reps: _reps,
        restSeconds: _rest,
        targetLoad: (load == null || load == 0) ? null : load,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.exerciseName.toUpperCase(), style: AppText.display(28)),
              if (widget.muscleGroup != null) Text(widget.muscleGroup!, style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              NumberStepper(
                key: const Key('item-sets'),
                label: 'Séries',
                value: _sets,
                min: 1,
                max: 20,
                onChanged: (v) => setState(() => _sets = v),
              ),
              const SizedBox(height: 8),
              NumberStepper(
                key: const Key('item-reps'),
                label: 'Repetições',
                value: _reps,
                min: 1,
                max: 100,
                onChanged: (v) => setState(() => _reps = v),
              ),
              const SizedBox(height: 8),
              NumberStepper(
                key: const Key('item-rest'),
                label: 'Descanso',
                value: _rest,
                min: 0,
                max: 600,
                step: 15,
                format: (v) => v == 0 ? 'Sem' : '$v s',
                onChanged: (v) => setState(() => _rest = v),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('item-load'),
                controller: _load,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(labelText: 'Carga sugerida em kg (opcional)', errorText: _error),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('item-notes'),
                controller: _notes,
                maxLines: 3,
                minLines: 1,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Observação para o aluno (opcional)', hintText: 'Ex.: descer devagar, pegada neutra'),
              ),
              const SizedBox(height: 12),
              PillButton(key: const Key('item-save'), label: widget.editing ? 'Salvar alterações' : 'Adicionar ao treino', onPressed: _save),
              if (widget.editing)
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    key: const Key('item-remove'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () => Navigator.of(context).pop(const PlanItemSheetResult(remove: true)),
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    label: const Text('Retirar do treino'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linha com rótulo, "−", valor e "+" (alvos de toque de 42 px).
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.step = 1,
    this.format,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String Function(int value)? format;

  @override
  Widget build(BuildContext context) {
    final text = format?.call(value) ?? '$value';
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(child: LabelText(label, size: 12)),
          CircleIconButton(
            icon: LucideIcons.minus,
            tooltip: 'Menos $label'.toLowerCase(),
            onPressed: value <= min ? null : () => onChanged((value - step).clamp(min, max)),
          ),
          SizedBox(
            width: 72,
            child: Text(text, textAlign: TextAlign.center, style: AppText.display(28)),
          ),
          CircleIconButton(
            icon: LucideIcons.plus,
            tooltip: 'Mais $label'.toLowerCase(),
            onPressed: value >= max ? null : () => onChanged((value + step).clamp(min, max)),
          ),
        ],
      ),
    );
  }
}
