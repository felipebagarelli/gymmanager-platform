import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/media/photo.dart';
import 'package:gymmanager_mobile/features/assistant/data/assistant_repository.dart';

/// Guarda a última requisição e responde com uma troca válida da IA.
class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? last;

  static const _body = '{"question":{"id":1,"role":"USER","body":"Foto do aparelho","createdAt":"2026-10-10T10:00:00","kind":"EQUIPMENT_PHOTO"},'
      '"answer":{"id":2,"role":"ASSISTANT","body":"{}","createdAt":"2026-10-10T10:00:00","kind":"EQUIPMENT_PHOTO",'
      '"equipment":{"recognized":true,"name":"Leg press","muscles":[],"setup":[],"steps":["a"],"inPlan":true}},"remainingToday":29}';

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(_body, 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 0x4A, 0x46]);

/// Contrato com o servidor (AiController.askMultipart): campos `question` (opcional) e `image`.
void main() {
  late _CaptureAdapter adapter;
  late AssistantRepository repository;

  setUp(() {
    adapter = _CaptureAdapter();
    repository = AssistantRepository(Dio()..httpClientAdapter = adapter);
  });

  FormData sentForm() => adapter.last!.data as FormData;

  test('foto com pergunta: POST multipart em /api/v1/ai/messages com os campos question e image', () async {
    final exchange = await repository.askWithPhoto(PickedPhoto(bytes: _jpeg, name: 'aparelho.jpg'), question: '  Como uso?  ');

    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.path, '/api/v1/ai/messages');
    expect(sentForm().fields.map((f) => (f.key, f.value)), [('question', 'Como uso?')]);
    expect(sentForm().files, hasLength(1));
    final file = sentForm().files.single;
    expect(file.key, 'image');
    expect(file.value.filename, 'aparelho.jpg');
    expect(file.value.contentType.toString(), 'image/jpeg');
    expect(file.value.length, _jpeg.length);
    // e a resposta estruturada é lida do JSON do servidor
    expect(exchange.answer.equipment!.name, 'Leg press');
    expect(exchange.remainingToday, 29);
  });

  test('foto sem pergunta (ou só espaços) não envia o campo question', () async {
    await repository.askWithPhoto(PickedPhoto(bytes: _jpeg, name: 'a.jpg'));
    expect(sentForm().fields, isEmpty);

    await repository.askWithPhoto(PickedPhoto(bytes: _jpeg, name: 'a.jpg'), question: '   ');
    expect(sentForm().fields, isEmpty);
    expect(sentForm().files.single.key, 'image');
  });

  test('o tipo da parte vem do conteúdo (PNG fica image/png), não da extensão', () async {
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0]);

    await repository.askWithPhoto(PickedPhoto(bytes: png, name: 'foto.jpg'));

    expect(sentForm().files.single.value.contentType.toString(), 'image/png');
  });

  test('a análise com imagem tem prazos maiores que o padrão', () async {
    await repository.askWithPhoto(PickedPhoto(bytes: _jpeg, name: 'a.jpg'));

    expect(adapter.last!.receiveTimeout, const Duration(seconds: 120));
    expect(adapter.last!.sendTimeout, const Duration(seconds: 60));
  });
}
