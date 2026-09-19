import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/features/assistant/application/assistant_providers.dart';
import 'package:gymmanager_mobile/features/assistant/data/assistant_repository.dart';
import 'package:gymmanager_mobile/features/assistant/domain/assistant.dart';
import 'package:gymmanager_mobile/features/assistant/presentation/assistant_page.dart';

AiMessage _m(int id, AiRole role, String body) =>
    AiMessage(id: id, role: role, body: body, createdAt: DateTime(2026, 9, 19, 10, id));

class FakeAssistantRepository extends AssistantRepository {
  FakeAssistantRepository({this.limit = 3}) : super(Dio());

  final int limit;
  final List<AiMessage> store = [];
  AppException? error;
  int _id = 1;

  int get used => store.where((m) => m.role == AiRole.user).length;

  @override
  Future<List<AiMessage>> history() async => [...store];

  @override
  Future<AiUsage> usage() async =>
      AiUsage(dailyLimit: limit, usedToday: used, remainingToday: limit - used);

  @override
  Future<AiExchange> ask(String question) async {
    if (error != null) throw error!;
    final q = _m(_id++, AiRole.user, question);
    final a = _m(_id++, AiRole.assistant, 'Resposta para: $question');
    store.addAll([q, a]);
    return AiExchange(question: q, answer: a, remainingToday: limit - used);
  }
}

Widget _app(FakeAssistantRepository repo) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [assistantRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: AssistantPage())),
    );

void main() {
  test('AiMessage/AiExchange/AiUsage fazem parse do JSON da API', () {
    final exchange = AiExchange.fromJson({
      'question': {'id': 1, 'role': 'USER', 'body': 'oi', 'createdAt': '2026-09-19T10:00:00'},
      'answer': {'id': 2, 'role': 'ASSISTANT', 'body': 'olá', 'createdAt': '2026-09-19T10:00:00'},
      'remainingToday': 29,
    });
    expect(exchange.question.role, AiRole.user);
    expect(exchange.answer.role, AiRole.assistant);
    expect(exchange.remainingToday, 29);
    expect(AiUsage.fromJson({'dailyLimit': 30, 'usedToday': 1, 'remainingToday': 29}).remainingToday, 29);
  });

  testWidgets('mostra aviso, estado vazio e contador de perguntas', (tester) async {
    await tester.pumpWidget(_app(FakeAssistantRepository()));
    await tester.pumpAndSettle();

    expect(find.text(assistantDisclaimer), findsOneWidget);
    expect(find.textContaining('Pergunte sobre seus exercícios'), findsOneWidget);
    expect(find.text('3 de 3 perguntas restantes hoje'), findsOneWidget);
  });

  testWidgets('pergunta, exibe a resposta e atualiza o contador', (tester) async {
    final repo = FakeAssistantRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('assistant-input')), 'Como agachar?');
    await tester.tap(find.byKey(const Key('assistant-send')));
    await tester.pumpAndSettle();

    expect(find.text('Como agachar?'), findsOneWidget);
    expect(find.text('Resposta para: Como agachar?'), findsOneWidget);
    expect(find.text('2 de 3 perguntas restantes hoje'), findsOneWidget);
  });

  testWidgets('erro da API vira mensagem amigavel e nao perde o texto digitado', (tester) async {
    final repo = FakeAssistantRepository()
      ..error = AppException('O assistente não está disponível no momento.', statusCode: 503);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('assistant-input')), 'Oi');
    await tester.tap(find.byKey(const Key('assistant-send')));
    await tester.pumpAndSettle();

    expect(find.text('O assistente não está disponível no momento.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Oi'), findsOneWidget);
  });

  testWidgets('sem perguntas restantes desabilita o envio', (tester) async {
    final repo = FakeAssistantRepository(limit: 1)..store.add(_m(1, AiRole.user, 'a'));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Você atingiu o limite de 1 perguntas hoje.'), findsOneWidget);
    final send = tester.widget<IconButton>(find.byKey(const Key('assistant-send')));
    expect(send.onPressed, isNull);
  });
}
