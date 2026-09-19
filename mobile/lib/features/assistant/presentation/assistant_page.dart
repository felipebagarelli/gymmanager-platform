import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_widgets.dart';
import '../application/assistant_providers.dart';
import '../domain/assistant.dart';

const assistantDisclaimer = 'O assistente é uma IA e não substitui seu personal nem orientação médica.';

class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _asking = false;
  String? _pendingQuestion;
  int _lastCount = -1;

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

  Future<void> _ask() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _asking) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _asking = true;
      _pendingQuestion = text;
    });
    _scrollToEnd();
    try {
      await ref.read(assistantControllerProvider.notifier).ask(text);
      _controller.clear();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(messageOf(error))));
    } finally {
      if (mounted) {
        setState(() {
          _asking = false;
          _pendingQuestion = null;
        });
        _scrollToEnd();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(assistantControllerProvider);
    final usage = ref.watch(assistantUsageProvider).value;
    final outOfQuota = usage != null && usage.remainingToday <= 0;

    return Column(
      children: [
        Container(
          key: const Key('assistant-disclaimer'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(assistantDisclaimer, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: history.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                ErrorRetry(error: error, onRetry: () => ref.invalidate(assistantControllerProvider)),
            data: (items) {
              final total = items.length + (_pendingQuestion != null ? 1 : 0) + (_asking ? 1 : 0);
              if (total != _lastCount) {
                _lastCount = total;
                _scrollToEnd();
              }
              if (total == 0) {
                return const EmptyState(
                  icon: Icons.smart_toy_outlined,
                  message: 'Pergunte sobre seus exercícios, técnica e treino.\nEx.: "Como faço o agachamento?"',
                );
              }
              return ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                children: [
                  for (final message in items) _Bubble(text: message.body, mine: message.role == AiRole.user),
                  if (_pendingQuestion != null) _Bubble(text: _pendingQuestion!, mine: true),
                  if (_asking) const _Typing(),
                ],
              );
            },
          ),
        ),
        if (usage != null)
          Text(
            outOfQuota
                ? 'Você atingiu o limite de ${usage.dailyLimit} perguntas hoje.'
                : '${usage.remainingToday} de ${usage.dailyLimit} perguntas restantes hoje',
            key: const Key('assistant-usage'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('assistant-input'),
                    controller: _controller,
                    enabled: !outOfQuota,
                    maxLength: 1000,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _ask(),
                    decoration: const InputDecoration(
                      hintText: 'Pergunte ao assistente',
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('assistant-send'),
                  tooltip: 'Enviar',
                  onPressed: (_asking || outOfQuota) ? null : _ask,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('assistant-typing'),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: SelectableText(text, style: TextStyle(color: mine ? scheme.onPrimary : scheme.onSurface)),
      ),
    );
  }
}
