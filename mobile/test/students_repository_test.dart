import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/features/trainer/students/data/students_repository.dart';
import 'package:gymmanager_mobile/features/trainer/students/domain/managed_student.dart';

/// Responde conforme o caminho e guarda todas as requisições.
class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String Function(RequestOptions options) body = (_) => '{}';

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(body(options), 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

const _student = '{"id":7,"email":"ana@example.com","name":"Ana","birthDate":"1995-03-21","phone":"11 9","goal":"Força",'
    '"height":1.68,"weight":61.5,"active":true,"status":"ACTIVE","weeklyGoal":3,"lastWorkoutAt":"2026-10-14T07:30:00"}';

void main() {
  late _Adapter adapter;
  late StudentsRepository repository;

  setUp(() {
    adapter = _Adapter();
    repository = StudentsRepository(Dio()..httpClientAdapter = adapter);
  });

  test('lista os alunos do personal e lê todos os campos', () async {
    adapter.body = (_) => '[$_student]';

    final students = await repository.list(5);

    expect(adapter.requests.single.path, '/api/v1/trainers/5/students');
    final s = students.single;
    expect(s.name, 'Ana');
    expect(s.birthDate, DateTime(1995, 3, 21));
    expect(s.height, 1.68);
    expect(s.linkStatus, LinkStatus.active);
    expect(s.weeklyGoal, 3);
    expect(s.lastWorkoutAt, DateTime(2026, 10, 14, 7, 30));
  });

  test('cadastrar envia e-mail e senha; com meta semanal, grava a meta em seguida', () async {
    adapter.body = (_) => _student;

    await repository.create(
      5,
      StudentDraft(name: 'Ana', birthDate: DateTime(1995, 3, 21), height: 1.68, weeklyGoal: 3),
      email: 'ana@example.com',
      password: 'senha1234',
    );

    expect(adapter.requests, hasLength(2));
    final create = adapter.requests[0];
    expect(create.method, 'POST');
    expect(create.path, '/api/v1/trainers/5/students');
    expect(create.data, containsPair('email', 'ana@example.com'));
    expect(create.data, containsPair('password', 'senha1234'));
    expect(create.data, containsPair('birthDate', '1995-03-21'));
    final goal = adapter.requests[1];
    expect(goal.method, 'PUT');
    expect(goal.path, '/api/v1/students/7');
    expect(goal.data, containsPair('weeklyGoal', 3));
  });

  test('cadastrar sem meta semanal faz uma requisição só', () async {
    adapter.body = (_) => _student;

    await repository.create(5, const StudentDraft(name: 'Ana'), email: 'ana@example.com', password: 'senha1234');

    expect(adapter.requests, hasLength(1));
  });

  test('editar sem meta pede para removê-la; com meta, envia o valor', () async {
    adapter.body = (_) => _student;

    await repository.update(7, const StudentDraft(name: 'Ana'));
    expect(adapter.requests.last.data, containsPair('clearWeeklyGoal', true));
    expect(adapter.requests.last.data, containsPair('weeklyGoal', null));

    await repository.update(7, const StudentDraft(name: 'Ana', weeklyGoal: 4));
    expect(adapter.requests.last.data, containsPair('clearWeeklyGoal', false));
    expect(adapter.requests.last.data, containsPair('weeklyGoal', 4));
  });

  test('desativar usa DELETE no aluno', () async {
    await repository.deactivate(7);

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/api/v1/students/7');
  });

  test('mensalidade: vale a assinatura mais recente de cada aluno', () async {
    adapter.body = (_) => '[{"studentId":7,"status":"PAST_DUE"},{"studentId":8,"status":"ACTIVE"},{"studentId":7,"status":"ACTIVE"}]';

    final tuition = await repository.tuition();

    expect(adapter.requests.single.path, '/api/v1/billing/subscriptions');
    expect(tuition, {7: TuitionStatus.overdue, 8: TuitionStatus.upToDate});
  });
}
