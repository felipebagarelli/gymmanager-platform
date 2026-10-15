import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/features/trainer/workouts/data/trainer_workouts_repository.dart';
import 'package:gymmanager_mobile/features/trainer/workouts/domain/workout_draft.dart';
import 'package:gymmanager_mobile/features/workouts/domain/workout.dart';

/// Responde conforme o caminho e guarda todas as requisições.
class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String Function(RequestOptions options) body = (_) => '{}';
  int status = 200;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(body(options), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

const _item = '{"id":100,"exerciseId":1,"workoutId":10,"reps":12,"sets":3,"position":1,"restSeconds":60,'
    '"targetLoad":22.5,"notes":"descer devagar","exerciseName":"Supino reto","muscleGroup":"Peito"}';

void main() {
  late _Adapter adapter;
  late TrainerWorkoutsRepository repository;

  setUp(() {
    adapter = _Adapter();
    repository = TrainerWorkoutsRepository(Dio()..httpClientAdapter = adapter);
  });

  Map<String, dynamic> sent() {
    final data = adapter.requests.last.data;
    return (data is String ? jsonDecode(data) : data) as Map<String, dynamic>;
  }

  test('lista os treinos com o número de exercícios e de alunos', () async {
    adapter.body = (_) => '[{"id":10,"name":"Treino A","trainerId":5,"exerciseCount":6,"studentCount":2}]';

    final workouts = await repository.list();

    expect(adapter.requests.single.path, '/workouts');
    expect(workouts.single.exerciseCount, 6);
    expect(workouts.single.studentCount, 2);
  });

  test('cria, renomeia e duplica treinos', () async {
    adapter.body = (_) => '{"id":12,"name":"Treino C","trainerId":5,"exerciseCount":0,"studentCount":0}';

    await repository.create('  Treino C ');
    expect(adapter.requests.last.method, 'POST');
    expect(sent(), {'name': 'Treino C'});

    await repository.rename(12, 'Treino C - Costas');
    expect(adapter.requests.last.method, 'PUT');
    expect(adapter.requests.last.path, '/workouts/12');

    await repository.duplicate(10);
    expect(adapter.requests.last.path, '/workouts/10/duplicate');
  });

  test('lê o plano com nome e grupo do exercício', () async {
    adapter.body = (_) => '[$_item]';

    final item = (await repository.plan(10)).single;

    expect(adapter.requests.single.path, '/workout-exercises/workout/10');
    expect(item.exerciseName, 'Supino reto');
    expect(item.muscleGroup, 'Peito');
    expect(item.targetLoad, 22.5);
    expect(planItemSummary(item), '3 × 12 · 60 s · 22,5 kg');
  });

  test('adicionar sem posição (vai para o fim) e observação em branco vira null', () async {
    adapter.body = (_) => _item;

    await repository.addItem(10, const PlanItemDraft(exerciseId: 1, sets: 4, reps: 8, restSeconds: 90, notes: '   '));

    expect(adapter.requests.last.path, '/workout-exercises');
    expect(sent(), {
      'exerciseId': 1,
      'workoutId': 10,
      'sets': 4,
      'reps': 8,
      'position': null,
      'restSeconds': 90,
      'targetLoad': null,
      'notes': null,
    });
  });

  test('reordenar envia todos os ids na nova ordem', () async {
    adapter.body = (_) => '[$_item]';

    await repository.reorder(10, [101, 100]);

    expect(adapter.requests.last.method, 'PUT');
    expect(adapter.requests.last.path, '/workout-exercises/workout/10/order');
    expect(sent(), {'workoutExerciseIds': [101, 100]});
  });

  test('alunos do treino: listar, atribuir e retirar', () async {
    adapter.body = (_) => '[{"id":1,"workoutId":10,"studentId":2,"status":"ACTIVE","startedAt":"2026-10-01T08:00:00","studentName":"Maria"}]';

    final assignees = await repository.assignees(10);
    expect(adapter.requests.last.path, '/workouts/10/assignments');
    expect(assignees.single.studentName, 'Maria');
    expect(assignees.single.startedAt, DateTime(2026, 10, 1, 8));

    adapter.body = (_) => '{}';
    await repository.assign(10, 3);
    expect(sent(), {'studentId': 3});

    await repository.unassign(10, 3);
    expect(adapter.requests.last.method, 'DELETE');
    expect(adapter.requests.last.path, '/workouts/10/assignments/3');
  });

  test('biblioteca: exercícios do personal vêm marcados como dele', () async {
    adapter.body = (_) => '[{"id":1,"name":"Supino","muscleGroup":"Peito","trainerId":null},'
        '{"id":9,"name":"Supino com pausa","muscleGroup":"Peito","trainerId":5}]';

    final library = await repository.exercises();

    expect(library.map((Exercise e) => e.custom), [false, true]);

    adapter.body = (_) => '{"id":10,"name":"Remada","muscleGroup":"Costas","trainerId":5}';
    await repository.createExercise(' Remada ', 'Costas ');
    expect(sent(), {'name': 'Remada', 'muscleGroup': 'Costas'});
  });

  test('erro do servidor vira AppException com a mensagem da API', () async {
    adapter.status = 409;
    adapter.body = (_) => '{"status":409,"message":"Este exercício está em um treino e não pode ser excluído."}';

    await expectLater(
      repository.deleteExercise(9),
      throwsA(isA<AppException>().having((e) => e.message, 'message', contains('não pode ser excluído'))),
    );
  });
}
