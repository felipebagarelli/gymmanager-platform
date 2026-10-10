import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../billing/presentation/overdue_view.dart';
import '../application/chat_providers.dart';
import '../domain/chat.dart';

String _time(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

DateTime _day(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// "Hoje", "Ontem" ou "Sexta · 9 de outubro".
String _dayLabel(DateTime value, DateTime now) {
  final day = _day(value);
  final today = _day(now);
  if (day == today) return 'Hoje';
  if (day == DateTime(today.year, today.month, today.day - 1)) return 'Ontem';
  return formatLongDate(value);
}

/// Chat do aluno com o personal (texto). O backend ainda não guarda anexos nem status "online".
class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(chatSummaryProvider);
    return SafeArea(
      bottom: false,
      child: summary.when(
        loading: () => const SkeletonList(heights: [64, 60, 80, 60]),
        error: (error, _) => isPaymentRequired(error)
            ? const OverdueView()
            : ErrorRetry(error: error, onRetry: () => ref.invalidate(chatSummaryProvider)),
        data: (conversation) => conversation == null
            ? const EmptyState(
                icon: LucideIcons.messageCircle,
                message: 'Você ainda não tem um personal vinculado para conversar.',
              )
            : _Conversation(conversation: conversation),
      ),
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
    final now = ref.watch(clockProvider)();

    return Column(
      children: [
        _Header(name: conversation.trainerName),
        Expanded(
          child: messages.when(
            loading: () => const SkeletonList(heights: [60, 80, 60, 80]),
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
                  icon: LucideIcons.messageCircle,
                  message: 'Nenhuma mensagem ainda.\nMande a primeira!',
                );
              }
              return ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 12),
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i == 0 || _day(items[i].createdAt) != _day(items[i - 1].createdAt))
                      _DaySeparator(label: _dayLabel(items[i].createdAt, now)),
                    _Bubble(message: items[i], trainerName: conversation.trainerName),
                  ],
                ],
              );
            },
          ),
        ),
        if (conversation.canSend)
          _Composer(
            controller: _controller,
            sending: _sending,
            hint: 'Escreva para ${conversation.trainerName.split(' ').first}',
            onSend: _send,
          )
        else
          const _ClosedNotice(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return Padding(
      key: const Key('chat-header'),
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 12, kScreenPadding, 10),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.sky, Color(0xFF2F8FBF)],
                ),
              ),
              child: Text(trimmed.isEmpty ? '?' : trimmed[0].toUpperCase(), style: AppText.display(19, color: AppColors.onVolt)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 17, weight: FontWeight.w600)),
                Text('Personal', style: AppText.body(size: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(child: LabelText(label, size: 12)),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.trainerName});

  final ChatMessage message;
  final String trainerName;

  @override
  Widget build(BuildContext context) {
    final mine = message.senderRole == ChatSender.student;
    final textColor = mine ? AppColors.onVolt : AppColors.textPrimary;
    const radius = Radius.circular(18);
    const tail = Radius.circular(6);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        label: '${mine ? 'Você' : trainerName}, ${_time(message.createdAt)}: ${message.body}',
        excludeSemantics: true,
        child: Container(
          key: Key('bubble-${message.id}'),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.84),
          decoration: BoxDecoration(
            color: mine ? AppColors.volt : AppColors.surface,
            border: mine ? null : Border.all(color: AppColors.borderSubtle),
            borderRadius: BorderRadius.only(
              topLeft: radius,
              topRight: radius,
              bottomLeft: mine ? radius : tail,
              bottomRight: mine ? tail : radius,
            ),
          ),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message.body, style: AppText.body(size: 14.5, weight: mine ? FontWeight.w500 : FontWeight.w400, color: textColor)),
              const SizedBox(height: 4),
              Text(_time(message.createdAt), style: AppText.body(size: 11, color: textColor.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.hint, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final String hint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(99),
          borderSide: BorderSide(color: color),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('chat-input'),
              controller: controller,
              maxLength: 2000,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: AppText.body(size: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.body(size: 15, color: AppColors.textMuted),
                counterText: '',
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                border: border(AppColors.borderStrong),
                enabledBorder: border(AppColors.borderStrong),
                focusedBorder: border(AppColors.volt),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final enabled = !sending && controller.text.trim().isNotEmpty;
              return Semantics(
                button: true,
                enabled: enabled,
                label: 'Enviar',
                excludeSemantics: true,
                child: GestureDetector(
                  key: const Key('chat-send'),
                  onTap: enabled ? onSend : null,
                  child: Opacity(
                    opacity: enabled ? 1 : 0.4,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(gradient: AppColors.ctaGradient, shape: BoxShape.circle),
                      child: const Icon(LucideIcons.send, size: 20, color: AppColors.onVolt),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClosedNotice extends StatelessWidget {
  const _ClosedNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 16),
      child: Container(
        key: const Key('chat-closed'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.lock, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Conversa encerrada: só é possível ler o histórico.',
                  style: AppText.body(size: 14, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
