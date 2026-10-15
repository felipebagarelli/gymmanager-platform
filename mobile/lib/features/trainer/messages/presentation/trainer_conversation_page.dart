import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/async_widgets.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../chat/application/chat_providers.dart';
import '../../../chat/domain/chat.dart';
import '../../../chat/presentation/chat_page.dart';

/// Conversa do personal com um aluno (a mesma tela de conversa do aluno, do outro lado).
class TrainerConversationPage extends ConsumerWidget {
  const TrainerConversationPage({super.key, required this.conversationId});

  final int conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(trainerConversationsProvider);
    void back() => context.canPop() ? context.pop() : context.go('/');

    return Scaffold(
      body: SafeArea(
        child: conversations.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => const SkeletonList(heights: [64, 60, 80, 60]),
          error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(trainerConversationsProvider)),
          data: (items) {
            final conversation = items.where((c) => c.id == conversationId).firstOrNull;
            if (conversation == null) {
              return const EmptyState(icon: LucideIcons.messageCircle, message: 'Conversa não encontrada.');
            }
            return ConversationView(
              conversation: conversation,
              viewer: ChatSender.trainer,
              otherName: conversation.studentName,
              otherSubtitle: 'Aluno',
              onBack: back,
            );
          },
        ),
      ),
    );
  }
}
