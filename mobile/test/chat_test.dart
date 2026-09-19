import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/chat/application/chat_providers.dart';
import 'package:gymmanager_mobile/features/chat/domain/chat.dart';
import 'package:gymmanager_mobile/features/chat/presentation/chat_page.dart';
import 'package:gymmanager_mobile/features/home/presentation/home_page.dart';

import 'support/fake_chat.dart';
import 'support/fakes.dart';

List<Override> overridesFor(FakeChatRepository chat) => [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage(
          StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1))),
        ),
      ),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      chatRepositoryProvider.overrideWithValue(chat),
      chatPollIntervalProvider.overrideWithValue(const Duration(milliseconds: 40)),
      chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
    ];

Future<ProviderContainer> containerFor(FakeChatRepository chat) async {
  final container = ProviderContainer(retry: (retryCount, error) => null, overrides: overridesFor(chat));
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);
  return container;
}

Future<void> settle([int ms = 150]) => Future<void>.delayed(Duration(milliseconds: ms));

class _NoConversationRepository extends FakeChatRepository {
  @override
  Future<List<ConversationSummary>> conversations() async => const [];
}

void main() {
  group('ChatMessagesController', () {
    test('carrega o historico e marca como lida ao abrir', () async {
      final chat = FakeChatRepository(
        initial: [msg(1, ChatSender.trainer, 'Oi'), msg(2, ChatSender.student, 'Olá')],
        unread: 1,
      );
      final container = await containerFor(chat);
      final sub = container.listen(chatMessagesProvider(7), (previous, next) {});
      addTearDown(sub.close);

      final messages = await container.read(chatMessagesProvider(7).future);
      await settle();

      expect(messages.map((m) => m.body), ['Oi', 'Olá']);
      expect(chat.markReadCalls, greaterThanOrEqualTo(1));
    });

    test('polling traz so mensagens novas (usa o ultimo id) e marca lida quando vem do personal', () async {
      final chat = FakeChatRepository(initial: [msg(1, ChatSender.trainer, 'Oi')]);
      final container = await containerFor(chat);
      final sub = container.listen(chatMessagesProvider(7), (previous, next) {});
      addTearDown(sub.close);
      await container.read(chatMessagesProvider(7).future);
      await settle();
      final readsBefore = chat.markReadCalls;

      chat.messagesStore.add(msg(2, ChatSender.trainer, 'Bom treino!'));
      await settle(250);

      expect(container.read(chatMessagesProvider(7)).value!.map((m) => m.body), ['Oi', 'Bom treino!']);
      expect(chat.afterCursors.whereType<int>(), isNotEmpty);
      expect(chat.markReadCalls, greaterThan(readsBefore));
    });

    test('send acrescenta a mensagem sem duplicar quando o polling a devolve', () async {
      final chat = FakeChatRepository(initial: [msg(1, ChatSender.trainer, 'Oi')]);
      final container = await containerFor(chat);
      final sub = container.listen(chatMessagesProvider(7), (previous, next) {});
      addTearDown(sub.close);
      await container.read(chatMessagesProvider(7).future);

      await container.read(chatMessagesProvider(7).notifier).send('Tudo certo');
      await settle(250);

      final bodies = container.read(chatMessagesProvider(7)).value!.map((m) => m.body).toList();
      expect(bodies, ['Oi', 'Tudo certo']);
    });

    test('erro ao enviar e propagado e as mensagens ficam como estavam', () async {
      final chat = FakeChatRepository(initial: [msg(1, ChatSender.trainer, 'Oi')])
        ..sendError = AppException('Esta conversa está encerrada.', statusCode: 409);
      final container = await containerFor(chat);
      final sub = container.listen(chatMessagesProvider(7), (previous, next) {});
      addTearDown(sub.close);
      await container.read(chatMessagesProvider(7).future);

      await expectLater(
        container.read(chatMessagesProvider(7).notifier).send('x'),
        throwsA(isA<AppException>().having((e) => e.statusCode, 'statusCode', 409)),
      );

      expect(container.read(chatMessagesProvider(7)).value, hasLength(1));
    });

    test('para de fazer polling quando a tela e fechada', () async {
      final chat = FakeChatRepository(initial: [msg(1, ChatSender.trainer, 'Oi')]);
      final container = await containerFor(chat);
      final sub = container.listen(chatMessagesProvider(7), (previous, next) {});
      await container.read(chatMessagesProvider(7).future);
      await settle();

      sub.close();
      await settle(100);
      final callsAfterClose = chat.afterCursors.length;
      await settle(300);

      expect(chat.afterCursors.length, callsAfterClose);
    });
  });

  group('ChatSummaryController', () {
    test('expoe o contador de nao lidas e a conversa unica', () async {
      final chat = FakeChatRepository(initial: [msg(1, ChatSender.trainer, 'Oi')], unread: 3);
      final container = await containerFor(chat);

      final summary = await container.read(chatSummaryProvider.future);

      expect(summary?.unreadCount, 3);
      expect(summary?.trainerName, 'João Personal');
      expect(summary?.canSend, isTrue);
    });
  });

  group('ChatMessage.fromJson', () {
    test('mapeia remetente e data', () {
      final message = ChatMessage.fromJson({
        'id': 5,
        'conversationId': 7,
        'senderRole': 'TRAINER',
        'body': 'Oi',
        'createdAt': '2026-09-19T18:14:10.6775568',
      });
      expect(message.senderRole, ChatSender.trainer);
      expect(message.createdAt.year, 2026);
    });
  });

  group('ChatPage', () {
    Widget app(FakeChatRepository chat) => ProviderScope(
          retry: (retryCount, error) => null,
          overrides: overridesFor(chat),
          child: const MaterialApp(home: Scaffold(body: ChatPage())),
        );

    Future<void> load(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> closeApp(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('mostra o historico, envia e limpa o campo', (tester) async {
      final chat = FakeChatRepository(initial: [msg(1, ChatSender.trainer, 'Como foi o treino?')]);
      await tester.pumpWidget(app(chat));
      await load(tester);

      expect(find.text('Conversa com João Personal'), findsOneWidget);
      expect(find.text('Como foi o treino?'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('chat-input')), '  Foi ótimo!  ');
      await tester.tap(find.byKey(const Key('chat-send')));
      await load(tester);

      expect(find.text('Foi ótimo!'), findsOneWidget);
      expect(chat.messagesStore.last.body, 'Foi ótimo!');
      expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text, isEmpty);
      await closeApp(tester);
    });

    testWidgets('mensagem em branco nao e enviada', (tester) async {
      final chat = FakeChatRepository();
      await tester.pumpWidget(app(chat));
      await load(tester);

      await tester.enterText(find.byKey(const Key('chat-input')), '   ');
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(chat.messagesStore, isEmpty);
      await closeApp(tester);
    });

    testWidgets('conversa encerrada esconde o campo e mostra o aviso', (tester) async {
      final chat = FakeChatRepository(initial: [msg(1, ChatSender.trainer, 'Até logo')], canSend: false);
      await tester.pumpWidget(app(chat));
      await load(tester);

      expect(find.byKey(const Key('chat-input')), findsNothing);
      expect(find.byKey(const Key('chat-closed')), findsOneWidget);
      expect(find.text('Até logo'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('erro do servidor ao enviar aparece como mensagem', (tester) async {
      final chat = FakeChatRepository()
        ..sendError = AppException('Esta conversa está encerrada: só é possível ler o histórico.', statusCode: 409);
      await tester.pumpWidget(app(chat));
      await load(tester);

      await tester.enterText(find.byKey(const Key('chat-input')), 'oi');
      await tester.tap(find.byKey(const Key('chat-send')));
      await load(tester);

      expect(find.textContaining('só é possível ler o histórico'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('sem conversa (sem personal vinculado) mostra estado vazio', (tester) async {
      await tester.pumpWidget(app(_NoConversationRepository()));
      await load(tester);

      expect(find.textContaining('personal vinculado'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('HomePage', () {
    Widget home(FakeChatRepository chat) => ProviderScope(
          retry: (retryCount, error) => null,
          overrides: overridesFor(chat),
          child: const MaterialApp(home: HomePage()),
        );

    testWidgets('a aba Mensagens mostra o contador de nao lidas', (tester) async {
      await tester.pumpWidget(home(FakeChatRepository(unread: 4)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('chat-unread')), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('sem nao lidas o contador fica oculto', (tester) async {
      await tester.pumpWidget(home(FakeChatRepository(unread: 0)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('chat-unread')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
