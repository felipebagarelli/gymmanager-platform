import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sessions/application/session_providers.dart';

bool _isToday(DateTime value) {
  final now = DateTime.now();
  final local = value.toLocal();
  return local.year == now.year && local.month == now.month && local.day == now.day;
}

/// Lembrete de que o aluno ainda não treinou hoje (ou está com um treino em andamento).
/// Some sozinho assim que houver uma sessão iniciada hoje.
class TodayReminderBanner extends ConsumerWidget {
  const TodayReminderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider).value;
    if (history == null) return const SizedBox.shrink();

    final trainedToday = history.any((session) => _isToday(session.startedAt));
    if (trainedToday) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('today-reminder'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined, color: scheme.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Você ainda não treinou hoje. Bora pra academia? 💪',
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
