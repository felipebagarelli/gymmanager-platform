import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/async_widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../chat/application/chat_providers.dart';
import '../../../chat/domain/chat.dart';

/// Abre a conversa com um aluno (cada vínculo tem uma conversa, criada pelo servidor).
Future<void> openConversationWith(BuildContext context, WidgetRef ref, int studentId) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final conversations = await ref.read(trainerConversationsProvider.future);
    final conversation = conversations.where((c) => c.studentId == studentId).firstOrNull;
    if (!context.mounted) return;
    if (conversation == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Conversa com este aluno ainda não disponível.')));
      return;
    }
    context.push('/trainer/messages/${conversation.id}');
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(messageOf(error))));
  }
}

/// Aba "Mensagens" do personal: uma conversa por aluno, a mais recente primeiro.
class TrainerMessagesPage extends ConsumerWidget {
  const TrainerMessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(trainerConversationsProvider);
    final unread = ref.watch(trainerUnreadProvider);
    final now = ref.watch(clockProvider)();

    return SafeArea(
      bottom: false,
      child: conversations.when(
        // ao recarregar (a cada poucos segundos) mantém a lista na tela
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const SkeletonList(heights: [56, 72, 72, 72]),
        error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(trainerConversationsProvider)),
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.refresh(trainerConversationsProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 24),
            children: [
              Text('MENSAGENS', style: AppText.display(36).copyWith(letterSpacing: 0.7)),
              Text(
                unread == 0 ? 'Conversas com seus alunos' : (unread == 1 ? '1 mensagem não lida' : '$unread mensagens não lidas'),
                key: const Key('messages-unread'),
                style: AppText.body(size: 13.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: EmptyState(
                    icon: LucideIcons.messageCircle,
                    message: 'Nenhuma conversa ainda.\nCada aluno cadastrado ganha uma conversa com você.',
                  ),
                )
              else
                for (final conversation in items) _ConversationTile(conversation: conversation, now: now),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.now});

  final ConversationSummary conversation;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final last = c.lastMessage;
    final unread = c.unreadCount > 0;
    final preview = last == null
        ? 'Nenhuma mensagem ainda'
        : '${last.senderRole == ChatSender.trainer ? 'Você: ' : ''}${last.body.replaceAll('\n', ' ')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        key: Key('conversation-${c.id}'),
        radius: 18,
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('/trainer/messages/${c.id}'),
        child: Row(
          children: [
            InitialsAvatar(name: c.studentName, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(c.studentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(size: 16, weight: unread ? FontWeight.w700 : FontWeight.w600)),
                      ),
                      if (last != null)
                        Text(formatChatTime(last.createdAt, now),
                            style: AppText.body(size: 12, color: unread ? AppColors.volt : AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(
                              size: 13.5,
                              weight: unread ? FontWeight.w600 : FontWeight.w400,
                              color: unread ? AppColors.textPrimary : AppColors.textMuted,
                            )),
                      ),
                      if (!c.canSend) ...[const SizedBox(width: 8), const TagChip('Encerrada')],
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          key: Key('unread-${c.id}'),
                          constraints: const BoxConstraints(minWidth: 22),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.volt, borderRadius: BorderRadius.circular(99)),
                          child: Text('${c.unreadCount}',
                              textAlign: TextAlign.center, style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.onVolt)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
