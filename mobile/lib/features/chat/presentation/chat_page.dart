import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_widgets.dart';
import '../application/chat_providers.dart';
import '../domain/chat.dart';

String _time(DateTime value) {
  final local = value.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final today = DateTime.now();
  final sameDay = local.year == today.year && local.month == today.month && local.day == today.day;
  return sameDay ? '$hh:$mm' : '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} $hh:$mm';
}

class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(chatSummaryProvider);

    return summary.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(chatSummaryProvider)),
      data: (conversation) => conversation == null
          ? const EmptyState(
              icon: Icons.chat_bubble_outline,
              message: 'Você ainda não tem um personal vinculado para conversar.',
            )
          : _Conversation(conversation: conversation),
    );
  }
}

class _Conversation extends ConsumerStatefulWidget {
  const _Conversation({required this.conversation});

  final ConversationSummary conversation;

  @override
  ConsumerState<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends ConsumerState<_Conversation> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  int _lastCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(chatMessagesProvider(widget.conversation.id).notifier).send(text);
      _controller.clear();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(messageOf(error))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final messages = ref.watch(chatMessagesProvider(conversation.id));

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text('Conversa com ${conversation.trainerName}',
              style: Theme.of(context).textTheme.titleSmall),
        ),
        Expanded(
          child: messages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorRetry(
              error: error,
              onRetry: () => ref.invalidate(chatMessagesProvider(conversation.id)),
            ),
            data: (items) {
              if (items.length != _lastCount) {
                _lastCount = items.length;
                _scrollToEnd();
              }
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.chat_bubble_outline,
                  message: 'Nenhuma mensagem ainda.\nMande a primeira!',
                );
              }
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, index) => _Bubble(message: items[index]),
              );
            },
          ),
        ),
        if (conversation.canSend)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('chat-input'),
                      controller: _controller,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Escreva uma mensagem',
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('chat-send'),
                    tooltip: 'Enviar',
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          )
        else
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Conversa encerrada: só é possível ler o histórico.',
                key: const Key('chat-closed'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.senderRole == ChatSender.student;
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: Key('bubble-${message.id}'),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.body, style: TextStyle(color: mine ? scheme.onPrimary : scheme.onSurface)),
            const SizedBox(height: 2),
            Text(
              _time(message.createdAt),
              style: TextStyle(fontSize: 11, color: (mine ? scheme.onPrimary : scheme.onSurface).withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
