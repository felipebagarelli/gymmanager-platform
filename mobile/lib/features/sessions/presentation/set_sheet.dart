import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../domain/workout_session.dart';

/// Resultado do sheet de série: valores informados, ou um pedido para remover a série.
class SetSheetResult {
  const SetSheetResult({this.reps = 0, this.loadKg, this.effort, this.remove = false});

  final int reps;

  /// null quando a carga é 0 (exercício sem carga, como flexão).
  final double? loadKg;
  final Effort? effort;
  final bool remove;
}

/// Abre o registro de uma série. Retorna null se o aluno cancelar.
///
/// [existing] != null abre em modo de edição (com o botão "Remover série").
Future<SetSheetResult?> showSetSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required int initialReps,
  required double initialLoad,
  Effort? initialEffort,
  bool editing = false,
}) {
  return showModalBottomSheet<SetSheetResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SetSheet(
      title: title,
      subtitle: subtitle,
      initialReps: initialReps,
      initialLoad: initialLoad,
      initialEffort: initialEffort,
      editing: editing,
    ),
  );
}

const double _loadStep = 2.5;

class _SetSheet extends StatefulWidget {
  const _SetSheet({
    required this.title,
    required this.subtitle,
    required this.initialReps,
    required this.initialLoad,
    required this.initialEffort,
    required this.editing,
  });

  final String title;
  final String subtitle;
  final int initialReps;
  final double initialLoad;
  final Effort? initialEffort;
  final bool editing;

  @override
  State<_SetSheet> createState() => _SetSheetState();
}

class _SetSheetState extends State<_SetSheet> {
  late final TextEditingController _reps = TextEditingController(text: '${widget.initialReps}');
  late final TextEditingController _load = TextEditingController(text: formatNumber(widget.initialLoad));
  late Effort? _effort = widget.initialEffort;
  String? _error;

  @override
  void dispose() {
    _reps.dispose();
    _load.dispose();
    super.dispose();
  }

  int? get _repsValue => int.tryParse(_reps.text.trim());
  double? get _loadValue => _load.text.trim().isEmpty ? 0 : parseDecimal(_load.text);

  void _stepReps(int delta) {
    final next = ((_repsValue ?? 0) + delta).clamp(0, 999);
    setState(() {
      _reps.text = '$next';
      _error = null;
    });
  }

  void _stepLoad(double delta) {
    final next = ((_loadValue ?? 0) + delta).clamp(0, 999).toDouble();
    setState(() {
      _load.text = formatNumber(next);
      _error = null;
    });
  }

  void _save() {
    final reps = _repsValue;
    final load = _loadValue;
    if (reps == null || reps < 0) return setState(() => _error = 'Informe as repetições');
    if (load == null || load < 0) return setState(() => _error = 'Carga inválida');
    Navigator.of(context).pop(SetSheetResult(reps: reps, loadKg: load == 0 ? null : load, effort: _effort));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // sobe junto com o teclado quando o aluno digita um valor
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title.toUpperCase(), style: AppText.display(30)),
              const SizedBox(height: 4),
              Text(widget.subtitle, style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              _StepperField(
                label: 'Repetições',
                controller: _reps,
                fieldKey: const Key('set-reps'),
                minusKey: const Key('reps-minus'),
                plusKey: const Key('reps-plus'),
                minusLabel: 'Menos uma repetição',
                plusLabel: 'Mais uma repetição',
                digitsOnly: true,
                onMinus: () => _stepReps(-1),
                onPlus: () => _stepReps(1),
                onChanged: () => setState(() => _error = null),
              ),
              const SizedBox(height: 10),
              _StepperField(
                label: 'Carga em kg',
                controller: _load,
                fieldKey: const Key('set-load'),
                minusKey: const Key('load-minus'),
                plusKey: const Key('load-plus'),
                minusLabel: 'Menos carga',
                plusLabel: 'Mais carga',
                digitsOnly: false,
                onMinus: () => _stepLoad(-_loadStep),
                onPlus: () => _stepLoad(_loadStep),
                onChanged: () => setState(() => _error = null),
              ),
              const SizedBox(height: 14),
              const LabelText('Como foi?'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final effort in Effort.values) ...[
                    if (effort != Effort.values.first) const SizedBox(width: 8),
                    Expanded(
                      child: _EffortButton(
                        effort: effort,
                        selected: _effort == effort,
                        // tocar de novo desmarca: o campo é opcional
                        onTap: () => setState(() => _effort = _effort == effort ? null : effort),
                      ),
                    ),
                  ],
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, key: const Key('set-error'), style: AppText.body(size: 13, color: AppColors.danger)),
              ],
              const SizedBox(height: 16),
              PillButton(key: const Key('set-save'), label: widget.editing ? 'Salvar alterações' : 'Salvar série', onPressed: _save),
              const SizedBox(height: 10),
              PillButton(
                key: const Key('set-cancel'),
                label: 'Cancelar',
                style: PillStyle.ghost,
                height: 46,
                onPressed: () => Navigator.of(context).pop(),
              ),
              if (widget.editing)
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    key: const Key('set-remove'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () => Navigator.of(context).pop(const SetSheetResult(remove: true)),
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    label: const Text('Remover série'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.label,
    required this.controller,
    required this.fieldKey,
    required this.minusKey,
    required this.plusKey,
    required this.minusLabel,
    required this.plusLabel,
    required this.digitsOnly,
    required this.onMinus,
    required this.onPlus,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final Key fieldKey;
  final Key minusKey;
  final Key plusKey;
  final String minusLabel;
  final String plusLabel;
  final bool digitsOnly;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          _RoundStep(key: minusKey, icon: LucideIcons.minus, label: minusLabel, onTap: onMinus),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // o número grande é um campo de texto: tocar nele permite digitar o valor
                TextField(
                  key: fieldKey,
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.numberWithOptions(decimal: !digitsOnly),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(digitsOnly ? r'\d' : r'[\d.,]'))],
                  style: AppText.display(60),
                  cursorColor: AppColors.volt,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => onChanged(),
                ),
                LabelText(label),
              ],
            ),
          ),
          _RoundStep(key: plusKey, icon: LucideIcons.plus, label: plusLabel, onTap: onPlus),
        ],
      ),
    );
  }
}

class _RoundStep extends StatelessWidget {
  const _RoundStep({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.overlay,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 52, height: 52, child: Icon(icon, size: 22, color: AppColors.textPrimary)),
        ),
      ),
    );
  }
}

class _EffortButton extends StatelessWidget {
  const _EffortButton({required this.effort, required this.selected, required this.onTap});

  final Effort effort;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: effort.label,
      excludeSemantics: true,
      child: InkWell(
        key: Key('effort-${effort.api}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? AppColors.mix(AppColors.volt, 0.08) : AppColors.surface,
            border: Border.all(color: selected ? AppColors.volt : AppColors.borderSubtle),
          ),
          child: Text(effort.label,
              style: AppText.body(size: 14, weight: FontWeight.w600, color: selected ? AppColors.volt : AppColors.textSecondary)),
        ),
      ),
    );
  }
}
