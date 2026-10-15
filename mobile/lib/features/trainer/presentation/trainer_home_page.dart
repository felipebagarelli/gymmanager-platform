import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/async_widgets.dart';
import '../../home/presentation/app_tab_bar.dart';
import '../application/trainer_tab_provider.dart';
import 'trainer_profile_page.dart';

/// Casca do modo personal: as 5 abas do personal no mesmo app do aluno.
class TrainerHomePage extends ConsumerStatefulWidget {
  const TrainerHomePage({super.key});

  @override
  ConsumerState<TrainerHomePage> createState() => _TrainerHomePageState();
}

class _TrainerHomePageState extends ConsumerState<TrainerHomePage> {
  /// Abas já visitadas: cada uma só é construída na primeira visita (e depois mantém o estado).
  final _visited = <int>{TrainerTab.students};

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(trainerTabProvider);
    _visited.add(index);

    Widget tab(int i, Widget page) => _visited.contains(i) ? page : const SizedBox.shrink();

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          // TODO(fase-b): B2 alunos, B4 treinos, B3 mensagens e B5 planos substituem estes avisos
          tab(TrainerTab.students, const _NextStage(title: 'Alunos', icon: LucideIcons.users)),
          tab(TrainerTab.workouts, const _NextStage(title: 'Treinos', icon: LucideIcons.dumbbell)),
          tab(TrainerTab.messages, const _NextStage(title: 'Mensagens', icon: LucideIcons.messageSquare)),
          tab(TrainerTab.plans, const _NextStage(title: 'Planos', icon: LucideIcons.wallet)),
          tab(TrainerTab.profile, const TrainerProfilePage()),
        ],
      ),
      bottomNavigationBar: AppTabBar(
        index: index,
        tabs: trainerTabs,
        messagesIndex: TrainerTab.messages,
        onSelected: ref.read(trainerTabProvider.notifier).select,
      ),
    );
  }
}

/// Aba ainda em construção no modo personal (só aparece no desenvolvimento, antes do lançamento).
class _NextStage extends StatelessWidget {
  const _NextStage({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 0),
            child: Text(title.toUpperCase(), style: AppText.display(36).copyWith(letterSpacing: 0.7)),
          ),
          Expanded(
            child: EmptyState(
              icon: icon,
              message: 'Em construção no app.\nPor enquanto, use o painel web para esta parte.',
            ),
          ),
        ],
      ),
    );
  }
}
