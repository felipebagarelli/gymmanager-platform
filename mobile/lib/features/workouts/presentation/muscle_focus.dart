import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/plan_stats.dart';

/// Barra de foco muscular: um segmento por grupo, proporcional ao número de séries.
/// A cor sozinha não informa nada: a legenda traz nome e porcentagem de cada grupo.
class MuscleFocusCard extends StatelessWidget {
  const MuscleFocusCard({super.key, required this.focus});

  final List<FocusShare> focus;

  @override
  Widget build(BuildContext context) {
    if (focus.isEmpty) return const SizedBox.shrink();

    return AppCard(
      key: const Key('muscle-focus'),
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelText('Foco muscular'),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < focus.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  // flex proporcional à porcentagem (mínimo 1 para o segmento nunca sumir)
                  flex: focus[i].percent < 1 ? 1 : focus[i].percent,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: muscleGroupColor(focus[i].group),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final share in focus)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: muscleGroupColor(share.group), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('${share.group} ${share.percent}%',
                        style: AppText.body(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
