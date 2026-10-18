import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../application/onboarding_providers.dart';
import '../domain/onboarding.dart';

enum _Step { goal, level, routine, location, body, health, result }

const _minuteOptions = [30, 45, 60, 75, 90];

/// "Antes de começar": objetivo, nível, rotina, onde treina, medidas e triagem de saúde.
/// Também serve para revisar depois (Perfil): vem preenchido com o que já foi respondido.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  _Step _step = _Step.goal;
  bool _prefilled = false;

  TrainingGoal? _goal;
  TrainingLevel? _level;
  int _days = 3;
  int _minutes = 45;
  TrainingLocation? _location;
  final Set<Equipment> _equipment = {};
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final List<bool?> _answers = List<bool?>.filled(screeningQuestions.length, null);

  bool _saving = false;
  String? _error;
  bool? _risk;

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _prefill(OnboardingStatus? status) {
    if (_prefilled) return;
    _prefilled = true;
    final p = status?.trainingProfile;
    if (p == null) return;
    _goal = p.goal;
    _level = p.level;
    _days = p.daysPerWeek;
    _minutes = p.minutesPerSession;
    _location = p.location;
    _equipment.addAll(p.equipment);
    if (p.height != null) _height.text = formatNumber(p.height!);
    if (p.weight != null) _weight.text = formatNumber(p.weight!);
  }

  bool get _canContinue => switch (_step) {
        _Step.goal => _goal != null,
        _Step.level => _level != null,
        _Step.routine => true,
        _Step.location => _location != null && (_location != TrainingLocation.home || _equipment.isNotEmpty),
        _Step.body => true,
        _Step.health => !_answers.contains(null),
        _Step.result => true,
      };

  String? _bodyError() {
    final h = _height.text.trim().isEmpty ? null : parseDecimal(_height.text);
    final w = _weight.text.trim().isEmpty ? null : parseDecimal(_weight.text);
    if (_height.text.trim().isNotEmpty && (h == null || h < 0.9 || h > 2.5)) return 'Altura em metros, por exemplo 1,70';
    if (_weight.text.trim().isNotEmpty && (w == null || w < 25 || w > 350)) return 'Peso em kg, por exemplo 68,5';
    return null;
  }

  Future<void> _next() async {
    setState(() => _error = null);
    switch (_step) {
      case _Step.body:
        final invalid = _bodyError();
        if (invalid != null) return setState(() => _error = invalid);
        await _save(() => ref.read(onboardingRepositoryProvider).saveTrainingProfile(TrainingProfile(
              goal: _goal!,
              level: _level!,
              daysPerWeek: _days,
              minutesPerSession: _minutes,
              location: _location!,
              equipment: _equipment,
              height: _height.text.trim().isEmpty ? null : parseDecimal(_height.text),
              weight: _weight.text.trim().isEmpty ? null : parseDecimal(_weight.text),
            )));
      case _Step.health:
        await _save(() async {
          _risk = await ref.read(onboardingRepositoryProvider).answerScreening([for (final a in _answers) a!]);
        });
      case _Step.result:
        // espera o status novo: com o antigo, o roteador traria de volta para cá
        await _save(() => ref.refresh(onboardingStatusProvider.future));
        if (mounted) context.go('/');
        return;
      default:
        setState(() => _step = _Step.values[_step.index + 1]);
    }
  }

  Future<void> _save(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      if (mounted && _step != _Step.result) setState(() => _step = _Step.values[_step.index + 1]);
    } catch (error) {
      if (mounted) setState(() => _error = messageOf(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() {
    if (_step == _Step.goal || _step == _Step.result) {
      context.canPop() ? context.pop() : context.go('/');
      return;
    }
    setState(() {
      _error = null;
      _step = _Step.values[_step.index - 1];
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(onboardingStatusProvider);
    if (status.isLoading && !status.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _prefill(status.value);

    final total = _Step.values.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  if (_step != _Step.result)
                    CircleIconButton(key: const Key('onboarding-back'), icon: LucideIcons.arrowLeft, tooltip: 'Voltar', onPressed: _back),
                  const SizedBox(width: 12),
                  if (_step != _Step.result)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: (_step.index + 1) / total,
                          minHeight: 6,
                          backgroundColor: AppColors.surface,
                          color: AppColors.volt,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  ..._content(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, key: const Key('onboarding-error'), style: AppText.body(size: 14, color: AppColors.danger)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: PillButton(
                key: const Key('onboarding-next'),
                label: switch (_step) {
                  _Step.health => _saving ? 'Enviando...' : 'Enviar respostas',
                  _Step.result => 'Começar',
                  _ => _saving ? 'Salvando...' : 'Continuar',
                },
                onPressed: _canContinue && !_saving ? _next : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content() => switch (_step) {
        _Step.goal => [
            _title('Qual é o seu objetivo?', 'Vamos montar tudo pensando nisso. Dá para mudar depois.'),
            for (final g in TrainingGoal.values)
              _Option(
                key: Key('goal-${g.name}'),
                title: g.label,
                subtitle: g.description,
                selected: _goal == g,
                onTap: () => setState(() => _goal = g),
              ),
          ],
        _Step.level => [
            _title('Qual é a sua experiência?', 'Isso define o volume e a carga inicial.'),
            for (final l in TrainingLevel.values)
              _Option(
                key: Key('level-${l.name}'),
                title: l.label,
                subtitle: l.description,
                selected: _level == l,
                onTap: () => setState(() => _level = l),
              ),
          ],
        _Step.routine => [
            _title('Sua rotina', 'Quantos dias por semana e quanto tempo por treino você tem.'),
            const LabelText('Dias por semana'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var d = 1; d <= 7; d++)
                  ChoiceChip(
                    key: Key('days-$d'),
                    label: Text('$d'),
                    selected: _days == d,
                    onSelected: (_) => setState(() => _days = d),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const LabelText('Tempo por treino'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _minuteOptions)
                  ChoiceChip(
                    key: Key('minutes-$m'),
                    label: Text('$m min'),
                    selected: _minutes == m,
                    onSelected: (_) => setState(() => _minutes = m),
                  ),
              ],
            ),
          ],
        _Step.location => [
            _title('Onde você vai treinar?', null),
            for (final l in TrainingLocation.values)
              _Option(
                key: Key('location-${l.name}'),
                title: l.label,
                subtitle: l.description,
                selected: _location == l,
                onTap: () => setState(() => _location = l),
              ),
            if (_location == TrainingLocation.home) ...[
              const SizedBox(height: 8),
              const LabelText('O que você tem em casa?'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in Equipment.values)
                    FilterChip(
                      key: Key('equipment-${e.name}'),
                      label: Text(e.label),
                      selected: _equipment.contains(e),
                      onSelected: (v) => setState(() => v ? _equipment.add(e) : _equipment.remove(e)),
                    ),
                ],
              ),
            ],
          ],
        _Step.body => [
            _title('Suas medidas', 'Opcional. Ajuda a acompanhar sua evolução.'),
            TextField(
              key: const Key('onboarding-height'),
              controller: _height,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
              decoration: const InputDecoration(labelText: 'Altura (m)', hintText: '1,70'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('onboarding-weight'),
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
              decoration: const InputDecoration(labelText: 'Peso (kg)', hintText: '68,5'),
            ),
          ],
        _Step.health => [
            _title('Sua saúde', 'Antes de treinar, responda com sinceridade. As respostas ficam só no seu cadastro.'),
            for (var i = 0; i < screeningQuestions.length; i++)
              _Question(
                key: Key('question-$i'),
                index: i,
                text: screeningQuestions[i],
                answer: _answers[i],
                onAnswer: (v) => setState(() => _answers[i] = v),
              ),
          ],
        _Step.result => [_Result(risk: _risk ?? false)],
      };

  Widget _title(String title, String? subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: AppText.display(32)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: AppText.body(size: 14, color: AppColors.textSecondary)),
            ],
          ],
        ),
      );
}

class _Option extends StatelessWidget {
  const _Option({super.key, required this.title, required this.subtitle, required this.selected, required this.onTap});

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        button: true,
        child: AppCard(
          radius: 18,
          padding: const EdgeInsets.all(14),
          borderColor: selected ? AppColors.volt : AppColors.borderSubtle,
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.body(size: 16, weight: FontWeight.w600)),
                    Text(subtitle, style: AppText.body(size: 13, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Icon(selected ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: 22, color: selected ? AppColors.volt : AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({super.key, required this.index, required this.text, required this.answer, required this.onAnswer});

  final int index;
  final String text;
  final bool? answer;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${index + 1}. $text', style: AppText.body(size: 14.5)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (value, label) in const [(false, 'Não'), (true, 'Sim')]) ...[
                  ChoiceChip(
                    key: Key('answer-$index-${value ? 'yes' : 'no'}'),
                    label: Text(label),
                    selected: answer == value,
                    onSelected: (_) => onAnswer(value),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.risk});

  final bool risk;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(risk ? LucideIcons.stethoscope : LucideIcons.circleCheck, size: 52, color: risk ? AppColors.ember : AppColors.volt),
        const SizedBox(height: 14),
        Text(risk ? 'PROCURE UMA AVALIAÇÃO' : 'TUDO PRONTO', key: const Key('onboarding-result'), style: AppText.display(32)),
        const SizedBox(height: 8),
        Text(
          risk
              ? 'Pelas suas respostas, o ideal é passar por uma avaliação médica (ou de um profissional de educação física) '
                  'antes de começar ou aumentar a intensidade dos treinos.\n\n'
                  'Por segurança, o app não vai gerar treinos automáticos para você. Você ainda pode registrar seus treinos '
                  'e, quando for liberado, responder o questionário de novo pelo Perfil.'
              : 'Suas respostas não indicam restrições. Se algo mudar na sua saúde, atualize o questionário pelo Perfil.\n\n'
                  'Exercício físico envolve riscos: comece leve, respeite seus limites e pare se sentir dor, tontura ou falta de ar.',
          style: AppText.body(size: 14.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
