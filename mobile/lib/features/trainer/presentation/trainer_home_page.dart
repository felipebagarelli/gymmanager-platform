import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/presentation/app_tab_bar.dart';
import '../application/trainer_tab_provider.dart';
import '../../chat/application/chat_providers.dart';
import '../messages/presentation/trainer_messages_page.dart';
import '../students/presentation/students_page.dart';
import '../plans/presentation/trainer_plans_page.dart';
import '../workouts/presentation/trainer_workouts_page.dart';
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
          tab(TrainerTab.students, const StudentsPage()),
          tab(TrainerTab.workouts, const TrainerWorkoutsPage()),
          tab(TrainerTab.messages, const TrainerMessagesPage()),
          tab(TrainerTab.plans, const TrainerPlansPage()),
          tab(TrainerTab.profile, const TrainerProfilePage()),
        ],
      ),
      bottomNavigationBar: AppTabBar(
        index: index,
        tabs: trainerTabs,
        messagesIndex: TrainerTab.messages,
        // a lista de conversas é consultada de tempos em tempos enquanto o personal está no app
        unreadMessages: ref.watch(trainerUnreadProvider),
        onSelected: ref.read(trainerTabProvider.notifier).select,
      ),
    );
  }
}
