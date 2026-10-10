import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assistant/presentation/assistant_page.dart';
import '../../billing/presentation/overdue_view.dart';
import '../../chat/application/chat_providers.dart';
import '../../chat/presentation/chat_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../sessions/presentation/history_page.dart';
import '../../workouts/presentation/my_workouts_page.dart';
import '../application/home_tab_provider.dart';
import 'app_tab_bar.dart';

/// Casca das 5 abas principais. As telas de fluxo (detalhe do treino, execução,
/// descanso, concluído, bloqueio) são rotas separadas e, por isso, ficam sem tab bar.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// Abas já visitadas. Histórico e Perfil só são construídos na primeira visita (e depois mantêm o estado):
  /// construí-los na abertura dispararia o cálculo de evolução e uma requisição por treino sem o aluno abrir a aba.
  final _visited = <int>{HomeTab.workouts};

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(homeTabProvider);
    _visited.add(index);
    final unread = ref.watch(chatSummaryProvider).value?.unreadCount ?? 0;
    // mensalidade em atraso bloqueia treinos e chat; histórico e perfil seguem acessíveis
    final overdue = ref.watch(overdueProvider);

    return Scaffold(
      // chat e assistente só são construídos quando abertos (polling / chamadas sob demanda)
      body: IndexedStack(
        index: index,
        children: [
          overdue ? const OverdueView() : const MyWorkoutsPage(),
          _visited.contains(HomeTab.history) ? const HistoryPage() : const SizedBox.shrink(),
          index == HomeTab.messages ? (overdue ? const OverdueView() : const ChatPage()) : const SizedBox.shrink(),
          index == HomeTab.assistant ? const AssistantPage() : const SizedBox.shrink(),
          _visited.contains(HomeTab.profile) ? const ProfilePage() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: AppTabBar(
        index: index,
        unreadMessages: unread,
        onSelected: ref.read(homeTabProvider.notifier).select,
      ),
    );
  }
}
