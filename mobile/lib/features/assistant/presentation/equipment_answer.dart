import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../domain/assistant.dart';

/// Resposta da IA para a foto de um aparelho: nome, músculos, preparação e passos numerados.
/// Se o aparelho não está no treino do aluno, oferece avisar o personal pelo chat.
class EquipmentAnswer extends StatelessWidget {
  const EquipmentAnswer({
    super.key,
    required this.messageId,
    required this.analysis,
    required this.trainerName,
    required this.notified,
    required this.onNotifyTrainer,
  });

  final int messageId;
  final EquipmentAnalysis analysis;

  /// Null quando o aluno não tem personal vinculado (não há para quem avisar).
  final String? trainerName;
  final bool notified;
  final VoidCallback? onNotifyTrainer;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    if (!a.recognized) {
      return Text(
        'Não consegui reconhecer esse aparelho pela foto. Tente outra foto, mais de perto e com boa luz, '
        'ou pergunte ao seu personal.',
        key: Key('equipment-unrecognized-$messageId'),
        style: AppText.body(size: 14.5).copyWith(height: 1.4),
      );
    }

    return Column(
      key: Key('equipment-$messageId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(a.name.toUpperCase(), style: AppText.display(26)),
        if (a.muscles.isNotEmpty) ...[
          const SizedBox(height: 12),
          const LabelText('Trabalha'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final muscle in a.muscles) TagChip(muscle, color: AppColors.volt)],
          ),
        ],
        if (a.setup.isNotEmpty) ...[
          const SizedBox(height: 14),
          const LabelText('Antes de começar'),
          const SizedBox(height: 6),
          for (final item in a.setup) _Bullet(item),
        ],
        const SizedBox(height: 14),
        const LabelText('Como fazer'),
        const SizedBox(height: 8),
        for (var i = 0; i < a.steps.length; i++) _Step(number: i + 1, text: a.steps[i]),
        if (!a.inPlan && trainerName != null) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 12),
          Text('Esse aparelho não está no seu treino. Quer pedir para $trainerName incluir?',
              key: Key('equipment-not-in-plan-$messageId'), style: AppText.body(size: 13.5, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          PillButton(
            key: Key('notify-trainer-$messageId'),
            label: notified ? 'Aviso enviado' : 'Avisar a $trainerName',
            icon: notified ? LucideIcons.check : LucideIcons.send,
            style: PillStyle.ghost,
            height: 44,
            expand: false,
            onPressed: notified ? null : onNotifyTrainer,
          ),
        ],
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 10, left: 2),
            child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle)),
          ),
          Expanded(child: Text(text, style: AppText.body(size: 14.5).copyWith(height: 1.35))),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.elevated, shape: BoxShape.circle),
            child: Text('$number', style: AppText.display(14, color: AppColors.volt)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(text, style: AppText.body(size: 14.5).copyWith(height: 1.35)))),
        ],
      ),
    );
  }
}
