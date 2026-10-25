import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/app_card.dart';
import '../../sessions/application/session_providers.dart';

/// Laranja enquanto o aluno não treinou hoje; verde depois que há sessão no dia.
/// Fica oculto só enquanto o histórico ainda carrega.
class TodayReminderBanner extends ConsumerWidget {
  const TodayReminderBanner({super.key, this.restDay = false});

  /// Hoje não tem treino marcado na semana do aluno.
  final bool restDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(trainingStatsProvider);
    if (stats == null) return const SizedBox.shrink();

    if (restDay && !stats.trainedToday) {
      return const InfoAlert(
        key: Key('today-rest'),
        kind: AlertKind.good,
        icon: LucideIcons.moon,
        text: 'Hoje é dia de descanso na sua semana.',
      );
    }
    return stats.trainedToday
        ? const InfoAlert(
            key: Key('today-done'),
            kind: AlertKind.good,
            icon: LucideIcons.check,
            text: 'Treino de hoje registrado. Descanse bem.',
          )
        : const InfoAlert(
            key: Key('today-reminder'),
            kind: AlertKind.warn,
            icon: LucideIcons.bell,
            text: 'Você ainda não treinou hoje. Bora?',
          );
  }
}
