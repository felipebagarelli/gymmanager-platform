import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/core/utils/formatters.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';
import 'package:gymmanager_mobile/features/workouts/domain/workout.dart';

void main() {
  group('PlanItem.fromJson', () {
    test('le todos os campos de planejamento', () {
      final item = PlanItem.fromJson({
        'id': 14,
        'exerciseId': 10,
        'workoutId': 15,
        'reps': 10,
        'sets': 3,
        'position': 2,
        'restSeconds': 60,
        'targetLoad': 20.5,
        'notes': 'controlar descida',
      });

      expect(item.id, 14);
      expect(item.sets, 3);
      expect(item.position, 2);
      expect(item.restSeconds, 60);
      expect(item.targetLoad, 20.5);
      expect(item.notes, 'controlar descida');
    });

    test('campos opcionais ausentes ou null viram null', () {
      final item = PlanItem.fromJson({
        'id': 15,
        'exerciseId': 10,
        'reps': 12,
        'sets': 4,
        'position': null,
        'restSeconds': null,
        'targetLoad': null,
        'notes': null,
      });

      expect(item.position, isNull);
      expect(item.restSeconds, isNull);
      expect(item.targetLoad, isNull);
      expect(item.notes, isNull);
    });

    test('aceita carga inteira vinda do JSON', () {
      final item = PlanItem.fromJson({'id': 1, 'exerciseId': 1, 'reps': 1, 'sets': 1, 'targetLoad': 30});
      expect(item.targetLoad, 30.0);
    });
  });

  group('WorkoutSession.fromJson', () {
    final json = {
      'id': 1,
      'workoutId': 15,
      'studentId': 2,
      'startedAt': '2026-09-19T16:07:45.870383',
      'finishedAt': null,
      'performances': [
        {'id': 2, 'workoutExerciseId': 15, 'setNumber': 2, 'reps': 10, 'loadKg': 25.0},
        {'id': 1, 'workoutExerciseId': 15, 'setNumber': 1, 'reps': 12, 'loadKg': 20.0},
        {'id': 3, 'workoutExerciseId': 16, 'setNumber': 1, 'reps': 8, 'loadKg': null},
      ],
    };

    test('sem finishedAt a sessao esta aberta', () {
      expect(WorkoutSession.fromJson(json).isOpen, isTrue);
    });

    test('com finishedAt a sessao esta encerrada', () {
      final finished = WorkoutSession.fromJson({...json, 'finishedAt': '2026-09-19T16:08:37.671172'});
      expect(finished.isOpen, isFalse);
    });

    test('setsOf filtra por exercicio e ordena pelo numero da serie', () {
      final session = WorkoutSession.fromJson(json);

      expect(session.setsOf(15).map((p) => p.setNumber), [1, 2]);
      expect(session.setsOf(16), hasLength(1));
      expect(session.setsOf(99), isEmpty);
    });
  });

  group('AppException.fromDio', () {
    RequestOptions request() => RequestOptions(path: '/x');

    test('usa a mensagem do corpo padronizado da API', () {
      final error = DioException(
        requestOptions: request(),
        response: Response(
          requestOptions: request(),
          statusCode: 409,
          data: {'status': 409, 'message': 'Esta sessão já foi finalizada.', 'path': '/x'},
        ),
      );

      final exception = AppException.fromDio(error);

      expect(exception.message, 'Esta sessão já foi finalizada.');
      expect(exception.statusCode, 409);
    });

    test('falha de conexao vira mensagem de rede', () {
      final exception = AppException.fromDio(
        DioException(requestOptions: request(), type: DioExceptionType.connectionError),
      );

      expect(exception.message, contains('Sem conexão'));
    });

    test('resposta sem corpo conhecido vira mensagem generica com o status', () {
      final exception = AppException.fromDio(
        DioException(
          requestOptions: request(),
          response: Response(requestOptions: request(), statusCode: 500, data: '<html>'),
        ),
      );

      expect(exception.message, 'Não foi possível concluir a operação.');
      expect(exception.statusCode, 500);
    });
  });

  group('formatters', () {
    test('formatLoad: inteiro sem casa, decimal preservado, null como traco', () {
      expect(formatLoad(20), '20 kg');
      expect(formatLoad(22.5), '22.5 kg');
      expect(formatLoad(null), '—');
    });

    test('parseDecimal aceita virgula e ponto', () {
      expect(parseDecimal('22,5'), 22.5);
      expect(parseDecimal(' 30.25 '), 30.25);
      expect(parseDecimal('abc'), isNull);
    });

    test('formatDuration', () {
      final start = DateTime(2026, 1, 1, 10, 0, 0);
      expect(formatDuration(start, start.add(const Duration(seconds: 20))), 'menos de 1 min');
      expect(formatDuration(start, start.add(const Duration(minutes: 47))), '47 min');
    });
  });
}
