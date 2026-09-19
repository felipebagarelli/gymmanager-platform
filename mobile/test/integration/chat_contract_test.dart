// Contrato do chat contra o backend REAL (desligado por padrao).
// Mesmos --dart-define do api_contract_test.dart. ATENCAO: envia uma mensagem real.
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/network/api_client.dart';
import 'package:gymmanager_mobile/features/auth/data/auth_repository.dart';
import 'package:gymmanager_mobile/features/chat/data/chat_repository.dart';
import 'package:gymmanager_mobile/features/chat/domain/chat.dart';

import '../support/fakes.dart';

const runApiTests = bool.fromEnvironment('RUN_API_TESTS');
const email = String.fromEnvironment('API_EMAIL');
const password = String.fromEnvironment('API_PASSWORD');

void main() {
  final skip = runApiTests ? null : 'defina --dart-define=RUN_API_TESTS=true para rodar contra a API real';

  test('aluno le a conversa, envia, pagina por id e marca como lida', skip: skip, () async {
    final storage = InMemoryTokenStorage();
    final dio = buildDio(storage: storage, onUnauthorized: () {});
    final login = await AuthRepository(dio).login(email, password);
    await storage.save(StoredSessionFactory.valid(login.token));
    final chat = ChatRepository(dio);

    final conversations = await chat.conversations();
    expect(conversations, hasLength(1));
    final conversation = conversations.single;
    expect(conversation.canSend, isTrue, reason: 'o aluno precisa estar ativo com vinculo ACTIVE');

    final before = await chat.messages(conversation.id);
    final lastId = before.isEmpty ? 0 : before.last.id;

    final sent = await chat.send(conversation.id, 'teste automatizado do app ${DateTime.now().toIso8601String()}');
    expect(sent.senderRole, ChatSender.student);
    expect(sent.id, greaterThan(lastId));

    final newer = await chat.messages(conversation.id, after: lastId);
    expect(newer.map((m) => m.id), contains(sent.id));
    expect(await chat.messages(conversation.id, after: sent.id), isEmpty);

    await chat.markRead(conversation.id);
    final after = (await chat.conversations()).single;
    expect(after.unreadCount, 0);
    expect(after.lastMessage?.id, greaterThanOrEqualTo(sent.id));

    await expectLater(
      chat.send(conversation.id, '   '),
      throwsA(isA<AppException>().having((e) => e.statusCode, 'statusCode', 400)),
    );
  });
}
