import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assistant/presentation/assistant_page.dart';
import '../../chat/application/chat_providers.dart';
import '../../chat/presentation/chat_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../sessions/presentation/history_page.dart';
import '../../workouts/presentation/my_workouts_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _index = 0;

  static const _titles = ['Meus treinos', 'Histórico', 'Mensagens', 'Assistente', 'Perfil'];
  static const _chatIndex = 2;
  static const _assistantIndex = 3;

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(chatSummaryProvider).value?.unreadCount ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      // o chat so e construido quando aberto: e ali que ha polling e marcacao de leitura
      body: IndexedStack(
        index: _index,
        children: [
          const MyWorkoutsPage(),
          const HistoryPage(),
          _index == _chatIndex ? const ChatPage() : const SizedBox.shrink(),
          _index == _assistantIndex ? const AssistantPage() : const SizedBox.shrink(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Treinos'),
          const NavigationDestination(icon: Icon(Icons.history), label: 'Histórico'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread', key: const Key('chat-unread')),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            label: 'Mensagens',
          ),
          const NavigationDestination(icon: Icon(Icons.smart_toy_outlined), label: 'Assistente'),
          const NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
