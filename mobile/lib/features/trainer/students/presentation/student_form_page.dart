import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/async_widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../../../core/widgets/skeleton.dart';
import '../application/students_providers.dart';
import '../domain/managed_student.dart';

/// Edição dos dados de um aluno pelo personal. Aluno novo não é cadastrado aqui: entra pelo link de
/// convite de um plano e cria a própria conta.
class StudentFormPage extends ConsumerWidget {
  const StudentFormPage({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = studentId;
    final student = ref.watch(managedStudentProvider(id));
    return student.when(
      loading: () => const Scaffold(body: SafeArea(child: SkeletonList())),
      error: (error, _) => Scaffold(
        body: SafeArea(child: ErrorRetry(error: error, onRetry: () => ref.invalidate(managedStudentProvider(id)))),
      ),
      data: (s) => _StudentForm(initial: s),
    );
  }
}

class _StudentForm extends ConsumerStatefulWidget {
  const _StudentForm({required this.initial});

  final ManagedStudent initial;

  @override
  ConsumerState<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends ConsumerState<_StudentForm> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _phone = TextEditingController(text: widget.initial.phone ?? '');
  late final _birth = TextEditingController(
    text: widget.initial.birthDate == null ? '' : formatBirthDate(widget.initial.birthDate!),
  );
  late final _goal = TextEditingController(text: widget.initial.goal ?? '');
  late final _height = TextEditingController(
    text: widget.initial.height == null ? '' : formatNumber(widget.initial.height!),
  );
  late final _weight = TextEditingController(
    text: widget.initial.weight == null ? '' : formatNumber(widget.initial.weight!),
  );

  /// 0 = sem meta.
  late int _weeklyGoal = widget.initial.weeklyGoal ?? 0;
  final _errors = <String, String>{};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _birth, _goal, _height, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _trimmed(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  /// Valida no app as mesmas regras da API, para o personal ver o erro no campo certo.
  StudentDraft? _validate() {
    _errors.clear();
    if (_name.text.trim().isEmpty) _errors['name'] = 'Informe o nome';
    DateTime? birth;
    if (_birth.text.trim().isNotEmpty) {
      birth = parseBirthDate(_birth.text);
      if (birth == null || birth.isAfter(DateTime.now())) _errors['birth'] = 'Use dd/mm/aaaa';
    }
    double? height;
    if (_height.text.trim().isNotEmpty) {
      height = parseDecimal(_height.text);
      if (height == null || height < 0.5 || height > 2.5) _errors['height'] = 'Altura em metros (ex.: 1,70)';
    }
    double? weight;
    if (_weight.text.trim().isNotEmpty) {
      weight = parseDecimal(_weight.text);
      if (weight == null || weight < 20 || weight > 400) _errors['weight'] = 'Peso em kg (ex.: 72,5)';
    }
    if (_errors.isNotEmpty) return null;
    return StudentDraft(
      name: _name.text.trim(),
      birthDate: birth,
      phone: _trimmed(_phone),
      goal: _trimmed(_goal),
      height: height,
      weight: weight,
      weeklyGoal: _weeklyGoal == 0 ? null : _weeklyGoal,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final draft = _validate();
    setState(() {});
    if (draft == null) return;
    setState(() => _saving = true);
    final repository = ref.read(studentsRepositoryProvider);
    ManagedStudent? saved;
    final ok = await runAction(context, () async {
      saved = await repository.update(widget.initial.id, draft);
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok || saved == null) return;
    refreshStudent(ref, saved!.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados salvos')),
    );
    context.pop();
  }

  Widget _field(String key, String label, TextEditingController controller,
      {String? hint, TextInputType? keyboard, bool obscure = false, List<TextInputFormatter>? formatters, String? helper}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key('field-$key'),
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        inputFormatters: formatters,
        style: AppText.body(size: 15.5),
        decoration: InputDecoration(labelText: label, hintText: hint, errorText: _errors[key], helperText: helper),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 0),
              child: Row(
                children: [
                  CircleIconButton(icon: LucideIcons.x, tooltip: 'Cancelar', onPressed: () => context.pop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('EDITAR ALUNO', style: AppText.display(26)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(kScreenPadding, 16, kScreenPadding, 16),
                children: [
                  _field('name', 'Nome', _name),
                  _field('phone', 'Telefone (opcional)', _phone, keyboard: TextInputType.phone),
                  _field('birth', 'Nascimento (opcional)', _birth, hint: 'dd/mm/aaaa', keyboard: TextInputType.datetime),
                  _field('goal', 'Objetivo (opcional)', _goal, hint: 'Ex.: hipertrofia, emagrecimento'),
                  Row(
                    children: [
                      Expanded(
                        child: _field('height', 'Altura em m', _height,
                            hint: '1,70', keyboard: const TextInputType.numberWithOptions(decimal: true)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field('weight', 'Peso em kg', _weight,
                            hint: '72,5', keyboard: const TextInputType.numberWithOptions(decimal: true)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _WeeklyGoalPicker(value: _weeklyGoal, onChanged: (v) => setState(() => _weeklyGoal = v)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 16),
              child: PillButton(
                key: const Key('save-student'),
                label: _saving ? 'Salvando…' : 'Salvar',
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Meta de treinos por semana: de "sem meta" a 14 (o limite da API).
class _WeeklyGoalPicker extends StatelessWidget {
  const _WeeklyGoalPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LabelText('Meta semanal'),
                const SizedBox(height: 4),
                Text(
                  value == 0 ? 'Sem meta' : '$value ${value == 1 ? 'treino' : 'treinos'} por semana',
                  key: const Key('weekly-goal-value'),
                  style: AppText.body(size: 16, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          CircleIconButton(
            key: const Key('weekly-goal-minus'),
            icon: LucideIcons.minus,
            tooltip: 'Menos um treino',
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
          ),
          const SizedBox(width: 8),
          CircleIconButton(
            key: const Key('weekly-goal-plus'),
            icon: LucideIcons.plus,
            tooltip: 'Mais um treino',
            onPressed: value < 14 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

