import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/routing/app_router.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/chat/application/chat_providers.dart';
import 'package:gymmanager_mobile/features/chat/domain/chat.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/trainer/students/application/students_providers.dart';
import 'package:gymmanager_mobile/features/trainer/students/domain/managed_student.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';

import 'support/fake_chat.dart';
import 'support/fake_repositories.dart';
import 'support/fakes.dart';
import 'trainer_students_test.dart' show FakeStudentsRepository;

final _now = DateTime(2026, 9, 20, 9);

ConversationSummary _conv(int id, int studentId, String name, {int unread = 0, bool canSend = true, ChatMessage? last}) =>
    ConversationSummary(
      id: id,
      trainerName: 'João Personal',
      unreadCount: unread,
      canSend: canSend,
      lastMessage: last,
      studentId: studentId,
      studentName: name,
    );

FakeTrainerChatRepository _chat() => FakeTrainerChatRepository(
      [
        _conv(11, 2, 'Maria Aluna', unread: 2, last: msg(2, ChatSender.student, 'Posso trocar o supino?')),
        _conv(12, 3, 'Bruno Silva', last: msg(3, ChatSender.trainer, 'Bom treino!')),
        _conv(13, 4, 'Carla Souza', canSend: false),
      ],
      messages: {
        11: [msg(1, ChatSender.trainer, 'Como foi ontem?'), msg(2, ChatSender.student, 'Posso trocar o supino?')],
        12: [msg(3, ChatSender.trainer, 'Bom treino!')],
      },
    );

StoredSession _trainerSession() =>
    StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)), role: 'TRAINER');

Widget _app(FakeTrainerChatRepository chat) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(_trainerSession())),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        chatRepositoryProvider.overrideWithValue(chat),
        chatPollIntervalProvider.overrideWithValue(const Duration(milliseconds: 40)),
        chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
        studentsRepositoryProvider.overrideWithValue(FakeStudentsRepository([
          const ManagedStudent(id: 2, email: 'maria@example.com', name: 'Maria Aluna', active: true),
        ])),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(theme: AppTheme.dark(), routerConfig: ref.watch(routerProvider)),
      ),
    );

Future<void> _load(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await _load(tester);
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _openMessagesTab(WidgetTester tester) async {
  await tester.tap(find.text('Mensagens'));
  await _load(tester);
}

void main() {
  group('trainerConversationsProvider', () {
    Future<ProviderContainer> container(FakeTrainerChatRepository chat, {String role = 'TRAINER'}) async {
      final c = ProviderContainer(retry: (retryCount, error) => null, overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(
          StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)), role: role),
        )),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        chatRepositoryProvider.overrideWithValue(chat),
        chatPollIntervalProvider.overrideWithValue(const Duration(milliseconds: 40)),
        chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
      ]);
      addTearDown(c.dispose);
      await c.read(authControllerProvider.future);
      return c;
    }

    test('soma as não lidas de todas as conversas', () async {
      final c = await container(_chat());
      final sub = c.listen(trainerConversationsProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(trainerConversationsProvider.future);

      expect(c.read(trainerUnreadProvider), 2);
    });

    test('aluno logado não consulta as conversas do personal', () async {
      final chat = _chat();
      final c = await container(chat, role: 'STUDENT');

      expect(await c.read(trainerConversationsProvider.future), isEmpty);
      expect(chat.conversationsCalls, 0);
    });

    test('ao receber pelo polling, só marca como lida se a mensagem vier do aluno', () async {
      final chat = _chat();
      final c = await container(chat);
      final sub = c.listen(chatMessagesProvider(12), (_, _) {});
      addTearDown(sub.close);
      await c.read(chatMessagesProvider(12).future);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(chat.markedRead, [12]); // abrir a conversa marca como lida

      // mensagem do próprio personal (ex.: enviada pelo painel web): nada a marcar
      chat.store[12]!.add(msg(20, ChatSender.trainer, 'Lembrete: alongar'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(chat.markedRead, [12]);

      chat.store[12]!.add(msg(21, ChatSender.student, 'Valeu!'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(chat.markedRead, [12, 12]);
      expect(c.read(chatMessagesProvider(12)).value!.map((m) => m.body), contains('Valeu!'));
    });
  });

  group('aba Mensagens do personal', () {
    testWidgets('lista as conversas com prévia, horário, não lidas e conversa encerrada', (tester) async {
      await _pump(tester, _app(_chat()));

      // contador na tab bar antes mesmo de abrir a aba
      expect(find.byKey(const Key('chat-unread')), findsOneWidget);

      await _openMessagesTab(tester);
      expect(find.text('MENSAGENS'), findsOneWidget);
      expect(find.text('2 mensagens não lidas'), findsOneWidget);
      expect(find.text('Maria Aluna'), findsOneWidget);
      expect(find.text('Posso trocar o supino?'), findsOneWidget);
      expect(find.text('Você: Bom treino!'), findsOneWidget);
      expect(find.text('Nenhuma mensagem ainda'), findsOneWidget);
      expect(find.byKey(const Key('unread-11')), findsOneWidget);
      expect(find.byKey(const Key('unread-12')), findsNothing);
      expect(find.text('Encerrada'), findsOneWidget);
      expect(find.text('Ontem'), findsWidgets); // mensagens de 19/09, hoje é 20/09
      await _close(tester);
    });

    testWidgets('sem alunos mostra o estado vazio', (tester) async {
      await _pump(tester, _app(FakeTrainerChatRepository([])));
      await _openMessagesTab(tester);

      expect(find.textContaining('Nenhuma conversa ainda'), findsOneWidget);
      expect(find.byKey(const Key('chat-unread')), findsNothing);
      await _close(tester);
    });

    testWidgets('abre a conversa, marca como lida e responde como personal', (tester) async {
      final chat = _chat();
      await _pump(tester, _app(chat));
      await _openMessagesTab(tester);

      await tester.tap(find.byKey(const Key('conversation-11')));
      await _load(tester);

      expect(find.text('Aluno'), findsOneWidget);
      expect(find.text('Como foi ontem?'), findsOneWidget);
      expect(chat.markedRead, contains(11));

      await tester.enterText(find.byKey(const Key('chat-input')), 'Pode sim, troca por halteres.');
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send')));
      await _load(tester);

      expect(chat.store[11]!.last.senderRole, ChatSender.trainer);
      expect(find.text('Pode sim, troca por halteres.'), findsOneWidget);

      // voltar devolve à lista, já sem não lidas
      await tester.tap(find.byKey(const Key('chat-back')));
      await _load(tester);
      expect(find.text('MENSAGENS'), findsOneWidget);
      expect(find.byKey(const Key('unread-11')), findsNothing);
      await _close(tester);
    });

    testWidgets('conversa encerrada não deixa escrever', (tester) async {
      await _pump(tester, _app(_chat()));
      await _openMessagesTab(tester);

      await tester.tap(find.byKey(const Key('conversation-13')));
      await _load(tester);

      expect(find.byKey(const Key('chat-input')), findsNothing);
      await _close(tester);
    });

    testWidgets('"Enviar mensagem" no perfil do aluno abre a conversa dele', (tester) async {
      await _pump(tester, _app(_chat()));
      await tester.tap(find.text('Maria Aluna'));
      await _load(tester);

      await tester.tap(find.byKey(const Key('message-student')));
      await _load(tester);

      expect(find.text('Como foi ontem?'), findsOneWidget);
      expect(find.byKey(const Key('chat-input')), findsOneWidget);
      await _close(tester);
    });
  });
}
