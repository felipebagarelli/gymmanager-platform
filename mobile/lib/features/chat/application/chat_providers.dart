import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/chat_repository.dart';
import '../domain/chat.dart';

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => ChatRepository(ref.watch(dioProvider)));

/// Intervalo de polling da conversa aberta e do resumo (contador). Sobrescrevivel em testes.
final chatPollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 3));
final chatSummaryIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 10));

/// Conversa do aluno com o personal (a unica), com o contador de nao lidas.
/// Se re-consulta sozinho enquanto estiver sendo observado.
class ChatSummaryController extends AsyncNotifier<ConversationSummary?> {
  @override
  Future<ConversationSummary?> build() async {
    final profile = ref.watch(currentStudentProvider);
    if (profile == null) return null;

    final timer = Timer(ref.watch(chatSummaryIntervalProvider), ref.invalidateSelf);
    ref.onDispose(timer.cancel);

    final conversations = await ref.read(chatRepositoryProvider).conversations();
    return conversations.isEmpty ? null : conversations.first;
  }
}

final chatSummaryProvider =
    AsyncNotifierProvider<ChatSummaryController, ConversationSummary?>(ChatSummaryController.new);

/// Mensagens da conversa aberta. So existe enquanto a tela esta aberta (autoDispose):
/// e nesse periodo que faz polling e marca as mensagens como lidas.
class ChatMessagesController extends AsyncNotifier<List<ChatMessage>> {
  ChatMessagesController(this.conversationId);

  final int conversationId;
  bool _disposed = false;
  bool _polling = false;

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  @override
  Future<List<ChatMessage>> build() async {
    ref.onDispose(() => _disposed = true);
    final timer = Timer.periodic(ref.watch(chatPollIntervalProvider), (_) => _poll());
    ref.onDispose(timer.cancel);

    final initial = await _repository.messages(conversationId);
    unawaited(_markRead());
    return initial;
  }

  Future<void> _markRead() async {
    try {
      await _repository.markRead(conversationId);
      if (!_disposed) ref.invalidate(chatSummaryProvider);
    } catch (_) {
      // best-effort: a proxima leitura tenta de novo
    }
  }

  List<ChatMessage> _merge(List<ChatMessage> current, List<ChatMessage> incoming) {
    final known = {for (final message in current) message.id};
    final fresh = [for (final message in incoming) if (!known.contains(message.id)) message];
    return fresh.isEmpty ? current : [...current, ...fresh];
  }

  Future<void> _poll() async {
    final current = state.value;
    if (_disposed || _polling || current == null) return;
    _polling = true;
    try {
      final lastId = current.isEmpty ? 0 : current.last.id;
      final incoming = await _repository.messages(conversationId, after: lastId);
      if (_disposed || incoming.isEmpty) return;
      state = AsyncData(_merge(state.value ?? current, incoming));
      if (incoming.any((message) => message.senderRole == ChatSender.trainer)) {
        await _markRead();
      }
    } catch (_) {
      // falha transitoria de rede: tenta de novo no proximo ciclo
    } finally {
      _polling = false;
    }
  }

  /// Lanca AppException em caso de erro (ex.: conversa encerrada).
  Future<void> send(String body) async {
    final message = await _repository.send(conversationId, body);
    state = AsyncData(_merge(state.value ?? const [], [message]));
    ref.invalidate(chatSummaryProvider);
  }
}

final chatMessagesProvider = AsyncNotifierProvider.autoDispose
    .family<ChatMessagesController, List<ChatMessage>, int>(ChatMessagesController.new);
