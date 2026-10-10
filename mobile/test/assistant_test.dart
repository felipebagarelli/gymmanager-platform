import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/media/photo.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/widgets/composer_widgets.dart';
import 'package:gymmanager_mobile/features/assistant/application/assistant_providers.dart';
import 'package:gymmanager_mobile/features/assistant/data/assistant_repository.dart';
import 'package:gymmanager_mobile/features/assistant/domain/assistant.dart';
import 'package:gymmanager_mobile/features/assistant/presentation/assistant_page.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/chat/application/chat_providers.dart';

import 'support/fake_chat.dart';
import 'support/fakes.dart';

AiMessage _m(int id, AiRole role, String body, {AiMessageKind kind = AiMessageKind.text, EquipmentAnalysis? equipment}) =>
    AiMessage(id: id, role: role, body: body, createdAt: DateTime(2026, 9, 19, 10, id), kind: kind, equipment: equipment);

const _legPress = EquipmentAnalysis(
  recognized: true,
  name: 'Leg press 45°',
  muscles: ['Quadríceps', 'Glúteos'],
  setup: ['Ajuste o encosto', 'Escolha a carga'],
  steps: ['Apoie os pés na plataforma', 'Empurre sem travar os joelhos'],
  inPlan: false,
);

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 0x4A, 0x46, 0x49, 0x46]);

class FakeAssistantRepository extends AssistantRepository {
  FakeAssistantRepository({this.limit = 3, this.equipment = _legPress}) : super(Dio());

  final int limit;
  EquipmentAnalysis equipment;
  final List<AiMessage> store = [];
  AppException? error;
  AppException? photoError;
  final List<String?> photoQuestions = [];
  int _id = 1;

  int get used => store.where((m) => m.role == AiRole.user).length;

  @override
  Future<List<AiMessage>> history() async => [...store];

  @override
  Future<AiUsage> usage() async => AiUsage(dailyLimit: limit, usedToday: used, remainingToday: limit - used);

  @override
  Future<AiExchange> ask(String question) async {
    if (error != null) throw error!;
    final q = _m(_id++, AiRole.user, question);
    final a = _m(_id++, AiRole.assistant, 'Resposta para: $question');
    store.addAll([q, a]);
    return AiExchange(question: q, answer: a, remainingToday: limit - used);
  }

  @override
  Future<AiExchange> askWithPhoto(PickedPhoto photo, {String? question}) async {
    if (photoError != null) throw photoError!;
    photoQuestions.add(question);
    final hasQuestion = question != null && question.trim().isNotEmpty;
    final q = _m(_id++, AiRole.user, hasQuestion ? question.trim() : 'Foto do aparelho', kind: AiMessageKind.equipmentPhoto);
    final a = _m(_id++, AiRole.assistant, '{}', kind: AiMessageKind.equipmentPhoto, equipment: equipment);
    store.addAll([q, a]);
    return AiExchange(question: q, answer: a, remainingToday: limit - used);
  }
}

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.photo, this.error});

  PickedPhoto? photo;
  Object? error;
  final List<PhotoSource> sources = [];

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    sources.add(source);
    if (error != null) throw error!;
    return photo;
  }
}

// PNG 1x1 válido: as prévias da tela decodificam a imagem de verdade
final _pixel = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

PickedPhoto _photo() => PickedPhoto(bytes: _pixel, name: 'aparelho.png');

Widget _app(FakeAssistantRepository repo, {FakePhotoPicker? picker, FakeChatRepository? chat}) {
  final List<Override> overrides = [
    assistantRepositoryProvider.overrideWithValue(repo),
    photoPickerProvider.overrideWithValue(picker ?? FakePhotoPicker()),
    if (chat != null) ...[
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage(StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)))),
      ),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      chatRepositoryProvider.overrideWithValue(chat),
      chatPollIntervalProvider.overrideWithValue(const Duration(hours: 1)),
      chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
    ],
  ];
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: overrides,
    child: const MaterialApp(home: Scaffold(body: AssistantPage())),
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Future<void> _attachPhoto(WidgetTester tester, {PhotoSource source = PhotoSource.gallery}) async {
  await tester.tap(find.byKey(const Key('assistant-plus')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(source == PhotoSource.camera ? 'pick-camera' : 'pick-gallery')));
  await tester.pumpAndSettle();
}

Future<void> _send(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('assistant-send')));
  await tester.pumpAndSettle();
}

bool _sendEnabled(WidgetTester tester) => tester.widget<SendButton>(find.byKey(const Key('assistant-send'))).enabled;

void main() {
  group('modelo e foto', () {
    test('AiMessage/AiExchange/AiUsage fazem parse do JSON da API', () {
      final exchange = AiExchange.fromJson({
        'question': {'id': 1, 'role': 'USER', 'body': 'oi', 'createdAt': '2026-09-19T10:00:00', 'kind': 'TEXT', 'equipment': null},
        'answer': {'id': 2, 'role': 'ASSISTANT', 'body': 'olá', 'createdAt': '2026-09-19T10:00:00'},
        'remainingToday': 29,
      });
      expect(exchange.question.role, AiRole.user);
      expect(exchange.answer.role, AiRole.assistant);
      expect(exchange.answer.kind, AiMessageKind.text);
      expect(exchange.answer.equipment, isNull);
      expect(exchange.remainingToday, 29);
      expect(AiUsage.fromJson({'dailyLimit': 30, 'usedToday': 1, 'remainingToday': 29}).remainingToday, 29);
    });

    test('resposta de foto traz a análise do aparelho', () {
      final message = AiMessage.fromJson({
        'id': 2,
        'role': 'ASSISTANT',
        'body': '{}',
        'createdAt': '2026-09-19T10:00:00',
        'kind': 'EQUIPMENT_PHOTO',
        'equipment': {
          'recognized': true,
          'name': 'Leg press 45°',
          'muscles': ['Quadríceps'],
          'setup': ['Ajuste o encosto'],
          'steps': ['Empurre'],
          'inPlan': true,
        },
      });
      expect(message.isPhoto, isTrue);
      expect(message.equipment!.name, 'Leg press 45°');
      expect(message.equipment!.muscles, ['Quadríceps']);
      expect(message.equipment!.inPlan, isTrue);
    });

    test('validação da foto: JPEG, PNG e WebP até 10 MB', () {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0]);
      final webp = Uint8List.fromList([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]);
      expect(photoMimeType(_jpeg), 'image/jpeg');
      expect(photoMimeType(png), 'image/png');
      expect(photoMimeType(webp), 'image/webp');
      validatePhoto(_jpeg);

      final heic = Uint8List.fromList([0, 0, 0, 0x18, ...'ftypheic'.codeUnits, 0, 0]);
      expect(() => validatePhoto(heic), throwsA(isA<AppException>()));
      expect(() => validatePhoto(Uint8List(0)), throwsA(isA<AppException>()));
      expect(() => validatePhoto(Uint8List.fromList('texto qualquer'.codeUnits)), throwsA(isA<AppException>()));

      final big = Uint8List(maxPhotoBytes + 1)..setRange(0, 3, [0xFF, 0xD8, 0xFF]);
      expect(() => validatePhoto(big), throwsA(isA<AppException>().having((e) => e.message, 'message', contains('10 MB'))));
    });
  });

  group('Personal IA', () {
    testWidgets('mostra aviso, estado vazio com sugestões e contador de perguntas', (tester) async {
      await _pump(tester, _app(FakeAssistantRepository()));

      expect(find.text('PERSONAL IA'), findsOneWidget);
      expect(find.text(assistantDisclaimer), findsOneWidget);
      expect(find.textContaining('Tire uma foto do aparelho na academia'), findsOneWidget);
      expect(find.byKey(const Key('suggestion-photo')), findsOneWidget);
      expect(find.text('Como faço o agachamento?'), findsOneWidget);
      expect(find.text('3 de 3 perguntas restantes hoje'), findsOneWidget);
    });

    testWidgets('tocar numa sugestão envia a pergunta na hora', (tester) async {
      final repo = FakeAssistantRepository();
      await _pump(tester, _app(repo));

      await tester.tap(find.byKey(const Key('suggestion-0')));
      await tester.pumpAndSettle();

      expect(find.text('Resposta para: Como faço o agachamento?'), findsOneWidget);
      expect(find.byKey(const Key('assistant-empty')), findsNothing);
      expect(find.text('2 de 3 perguntas restantes hoje'), findsOneWidget);
    });

    testWidgets('pergunta, exibe a resposta e atualiza o contador', (tester) async {
      final repo = FakeAssistantRepository();
      await _pump(tester, _app(repo));

      await tester.enterText(find.byKey(const Key('assistant-input')), 'Como agachar?');
      await tester.pump();
      await _send(tester);

      expect(find.text('Como agachar?'), findsOneWidget);
      expect(find.text('Resposta para: Como agachar?'), findsOneWidget);
      expect(find.text('2 de 3 perguntas restantes hoje'), findsOneWidget);
    });

    testWidgets('IA indisponível (503) mostra o aviso amigável e não perde o texto digitado', (tester) async {
      final repo = FakeAssistantRepository()..error = AppException('O assistente não está disponível no momento.', statusCode: 503);
      await _pump(tester, _app(repo));

      await tester.enterText(find.byKey(const Key('assistant-input')), 'Oi');
      await tester.pump();
      await _send(tester);

      expect(find.text('Personal IA indisponível no momento. Tente novamente mais tarde.'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Oi'), findsOneWidget);
    });

    testWidgets('outros erros da API viram mensagem e o aviso de indisponível some ao tentar de novo', (tester) async {
      final repo = FakeAssistantRepository()..error = AppException('O assistente não está disponível no momento.', statusCode: 503);
      await _pump(tester, _app(repo));
      await tester.enterText(find.byKey(const Key('assistant-input')), 'Oi');
      await tester.pump();
      await _send(tester);
      expect(find.byKey(const Key('assistant-unavailable')), findsOneWidget);

      repo.error = AppException('Você atingiu o limite de 30 perguntas por dia. Volte amanhã!', statusCode: 429);
      await _send(tester);

      expect(find.byKey(const Key('assistant-unavailable')), findsNothing);
      expect(find.text('Você atingiu o limite de 30 perguntas por dia. Volte amanhã!'), findsOneWidget);
    });

    testWidgets('sem perguntas restantes desabilita o envio, o campo e o "+"', (tester) async {
      final repo = FakeAssistantRepository(limit: 1)..store.add(_m(1, AiRole.user, 'a'));
      await _pump(tester, _app(repo));

      expect(find.text('Você atingiu o limite de 1 perguntas hoje.'), findsOneWidget);
      expect(_sendEnabled(tester), isFalse);
      expect(tester.widget<TextField>(find.descendant(of: find.byKey(const Key('assistant-input')), matching: find.byType(TextField))).enabled, isFalse);
      await tester.tap(find.byKey(const Key('assistant-plus')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plus-menu')), findsNothing);
    });
  });

  group('foto do aparelho', () {
    testWidgets('"+" abre o menu; escolher da galeria mostra a prévia e permite remover', (tester) async {
      final picker = FakePhotoPicker(photo: _photo());
      await _pump(tester, _app(FakeAssistantRepository(), picker: picker));
      expect(_sendEnabled(tester), isFalse);

      await tester.tap(find.byKey(const Key('assistant-plus')));
      await tester.pumpAndSettle();
      expect(find.text('Tirar foto'), findsOneWidget);
      expect(find.text('Escolher da galeria'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pick-gallery')));
      await tester.pumpAndSettle();
      expect(picker.sources, [PhotoSource.gallery]);
      expect(find.byKey(const Key('plus-menu')), findsNothing);
      expect(find.byKey(const Key('attachment-preview')), findsOneWidget);
      expect(find.text('Pergunte sobre a foto (opcional)'), findsOneWidget);
      expect(_sendEnabled(tester), isTrue); // foto sozinha basta

      await tester.tap(find.byKey(const Key('attachment-remove')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attachment-preview')), findsNothing);
      expect(_sendEnabled(tester), isFalse);
    });

    testWidgets('a sugestão "Foto do aparelho" abre o mesmo menu', (tester) async {
      await _pump(tester, _app(FakeAssistantRepository()));

      await tester.tap(find.byKey(const Key('suggestion-photo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('plus-menu')), findsOneWidget);
    });

    testWidgets('tirar foto usa a câmera', (tester) async {
      final picker = FakePhotoPicker(photo: _photo());
      await _pump(tester, _app(FakeAssistantRepository(), picker: picker));

      await _attachPhoto(tester, source: PhotoSource.camera);

      expect(picker.sources, [PhotoSource.camera]);
      expect(find.byKey(const Key('attachment-preview')), findsOneWidget);
    });

    testWidgets('cancelar o seletor não anexa nada; erro do seletor vira mensagem', (tester) async {
      final picker = FakePhotoPicker();
      await _pump(tester, _app(FakeAssistantRepository(), picker: picker));

      await _attachPhoto(tester);
      expect(find.byKey(const Key('attachment-preview')), findsNothing);

      picker.error = AppException('Formato de imagem não suportado. Use uma foto JPG, PNG ou WebP.');
      await _attachPhoto(tester);
      expect(find.text('Formato de imagem não suportado. Use uma foto JPG, PNG ou WebP.'), findsOneWidget);
      expect(find.byKey(const Key('attachment-preview')), findsNothing);
    });

    testWidgets('enviar a foto mostra a resposta estruturada e conta como uma pergunta', (tester) async {
      final repo = FakeAssistantRepository();
      await _pump(tester, _app(repo, picker: FakePhotoPicker(photo: _photo())));
      await _attachPhoto(tester);

      await _send(tester);

      expect(repo.photoQuestions, ['']);
      expect(find.text('Foto do aparelho'), findsOneWidget); // fala do aluno, sem a imagem
      expect(find.text('LEG PRESS 45°'), findsOneWidget);
      expect(find.text('Quadríceps'), findsOneWidget);
      expect(find.text('Glúteos'), findsOneWidget);
      expect(find.text('Antes de começar'.toUpperCase()), findsOneWidget);
      expect(find.text('Ajuste o encosto'), findsOneWidget);
      expect(find.text('Apoie os pés na plataforma'), findsOneWidget);
      expect(find.text('Empurre sem travar os joelhos'), findsOneWidget);
      expect(find.text('2 de 3 perguntas restantes hoje'), findsOneWidget);
      expect(find.byKey(const Key('attachment-preview')), findsNothing); // anexo some depois de enviado
    });

    testWidgets('a pergunta digitada vai junto da foto', (tester) async {
      final repo = FakeAssistantRepository();
      await _pump(tester, _app(repo, picker: FakePhotoPicker(photo: _photo())));
      await _attachPhoto(tester);
      await tester.enterText(find.byKey(const Key('assistant-input')), '  Como ajusto o banco?  ');
      await tester.pump();

      await _send(tester);

      expect(repo.photoQuestions, ['Como ajusto o banco?']);
      expect(find.text('Como ajusto o banco?'), findsOneWidget);
    });

    testWidgets('erro do servidor ao enviar a foto mantém a foto para tentar de novo', (tester) async {
      final repo = FakeAssistantRepository()..photoError = AppException('Formato de imagem não suportado.', statusCode: 400);
      await _pump(tester, _app(repo, picker: FakePhotoPicker(photo: _photo())));
      await _attachPhoto(tester);

      await _send(tester);

      expect(find.text('Formato de imagem não suportado.'), findsOneWidget);
      expect(find.byKey(const Key('attachment-preview')), findsOneWidget);
    });

    testWidgets('aparelho fora do treino: "Avisar a <personal>" manda a mensagem pelo chat', (tester) async {
      final repo = FakeAssistantRepository();
      final chat = FakeChatRepository();
      await _pump(tester, _app(repo, picker: FakePhotoPicker(photo: _photo()), chat: chat));
      await _attachPhoto(tester);
      await _send(tester);

      expect(find.text('Esse aparelho não está no seu treino. Quer pedir para João Personal incluir?'), findsOneWidget);
      await tester.tap(find.textContaining('AVISAR A JOÃO PERSONAL'));
      await tester.pumpAndSettle();

      expect(chat.messagesStore, hasLength(1));
      expect(chat.messagesStore.single.body, contains('Leg press 45°'));
      expect(find.text('Aviso enviado para João Personal'), findsOneWidget);
      expect(find.text('AVISO ENVIADO'), findsOneWidget);
    });

    testWidgets('aparelho que está no treino não oferece avisar o personal', (tester) async {
      final repo = FakeAssistantRepository(
        equipment: const EquipmentAnalysis(
          recognized: true,
          name: 'Supino reto',
          muscles: ['Peitoral'],
          setup: [],
          steps: ['Desça a barra'],
          inPlan: true,
        ),
      );
      await _pump(tester, _app(repo, picker: FakePhotoPicker(photo: _photo()), chat: FakeChatRepository()));
      await _attachPhoto(tester);
      await _send(tester);

      expect(find.text('SUPINO RETO'), findsOneWidget);
      expect(find.textContaining('Avisar a'), findsNothing);
      expect(find.textContaining('não está no seu treino'), findsNothing);
    });

    testWidgets('aparelho não reconhecido: avisa que não reconheceu em vez de chutar', (tester) async {
      final repo = FakeAssistantRepository(
        equipment: const EquipmentAnalysis(recognized: false, name: '', muscles: [], setup: [], steps: [], inPlan: false),
      );
      await _pump(tester, _app(repo, picker: FakePhotoPicker(photo: _photo())));
      await _attachPhoto(tester);
      await _send(tester);

      expect(find.textContaining('Não consegui reconhecer esse aparelho'), findsOneWidget);
      expect(find.textContaining('Avisar a'), findsNothing);
    });

    testWidgets('histórico traz as fotos anteriores como texto + resposta estruturada', (tester) async {
      final repo = FakeAssistantRepository()
        ..store.addAll([
          _m(1, AiRole.user, 'Foto do aparelho', kind: AiMessageKind.equipmentPhoto),
          _m(2, AiRole.assistant, '{}', kind: AiMessageKind.equipmentPhoto, equipment: _legPress),
        ]);
      await _pump(tester, _app(repo, chat: FakeChatRepository()));

      expect(find.text('Foto do aparelho'), findsOneWidget);
      expect(find.text('LEG PRESS 45°'), findsOneWidget);
      expect(find.byKey(const Key('assistant-empty')), findsNothing);
    });
  });
}
