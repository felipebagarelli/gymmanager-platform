import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../../core/media/photo.dart';
import '../data/assistant_repository.dart';
import '../domain/assistant.dart';

final assistantRepositoryProvider =
    Provider<AssistantRepository>((ref) => AssistantRepository(ref.watch(dioProvider)));

/// Quantas perguntas restam hoje. Reconsultado apos cada pergunta.
final assistantUsageProvider = FutureProvider.autoDispose<AiUsage>((ref) {
  return ref.watch(assistantRepositoryProvider).usage();
});

/// Historico privado do aluno com o assistente (carregado ao abrir a aba).
class AssistantController extends AsyncNotifier<List<AiMessage>> {
  @override
  Future<List<AiMessage>> build() async {
    final profile = ref.watch(currentStudentProvider);
    if (profile == null) return const [];
    return ref.read(assistantRepositoryProvider).history();
  }

  /// Lanca AppException (limite diario, IA indisponivel, falha do provedor...).
  Future<void> ask(String question) async {
    final exchange = await ref.read(assistantRepositoryProvider).ask(question);
    state = AsyncData([...state.value ?? const [], exchange.question, exchange.answer]);
    ref.invalidate(assistantUsageProvider);
  }

  /// Foto do aparelho (texto opcional). A imagem só passa por aqui: o servidor não a guarda.
  Future<void> askWithPhoto(PickedPhoto photo, {String? question}) async {
    final exchange = await ref.read(assistantRepositoryProvider).askWithPhoto(photo, question: question);
    state = AsyncData([...state.value ?? const [], exchange.question, exchange.answer]);
    ref.invalidate(assistantUsageProvider);
  }
}

final assistantControllerProvider =
    AsyncNotifierProvider<AssistantController, List<AiMessage>>(AssistantController.new);
