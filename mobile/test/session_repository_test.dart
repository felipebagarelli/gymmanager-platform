import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/features/sessions/data/session_repository.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';

/// Guarda a última requisição e responde 200 vazio.
class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _CaptureAdapter adapter;
  late SessionRepository repository;

  setUp(() {
    adapter = _CaptureAdapter();
    repository = SessionRepository(Dio()..httpClientAdapter = adapter);
  });

  group('updatePerformance e o "Como foi?"', () {
    test('com esforço escolhido envia o valor e não pede para apagar', () async {
      await repository.updatePerformance(7, 99, setNumber: 1, reps: 10, loadKg: 20, effort: Effort.hard);

      expect(adapter.last!.method, 'PUT');
      expect(adapter.last!.path, '/api/v1/workout-sessions/7/performances/99');
      expect(adapter.last!.data, containsPair('effort', 'HARD'));
      expect(adapter.last!.data, containsPair('clearEffort', false));
    });

    test('sem esforço (desmarcado) pede explicitamente para apagar o valor gravado', () async {
      await repository.updatePerformance(7, 99, setNumber: 1, reps: 10, loadKg: 20);

      expect(adapter.last!.data, containsPair('effort', null));
      expect(adapter.last!.data, containsPair('clearEffort', true));
    });
  });
}
