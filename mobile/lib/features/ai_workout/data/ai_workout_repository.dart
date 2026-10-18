import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';

/// Pode pedir uma proposta agora? Se não, o motivo (texto) e o código (para o app oferecer o caminho).
class ProposalEligibility {
  const ProposalEligibility({
    required this.allowed,
    this.reason,
    this.reasonCode,
    required this.usedThisMonth,
    this.monthlyLimit,
    this.pro = false,
  });

  final bool allowed;
  final String? reason;

  /// HAS_TRAINER, MINOR, NO_PROFILE, NO_SCREENING, HEALTH_RISK, FREE_LIMIT, PRO_LIMIT.
  final String? reasonCode;
  final int usedThisMonth;
  final int? monthlyLimit;
  final bool pro;

  factory ProposalEligibility.fromJson(Map<String, dynamic> json) => ProposalEligibility(
        allowed: json['allowed'] as bool? ?? false,
        reason: json['reason'] as String?,
        reasonCode: json['reasonCode'] as String?,
        usedThisMonth: (json['usedThisMonth'] as num?)?.toInt() ?? 0,
        monthlyLimit: (json['monthlyLimit'] as num?)?.toInt(),
        pro: json['pro'] as bool? ?? false,
      );
}

class ProposedExercise {
  const ProposedExercise({
    required this.name,
    this.muscleGroup,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    this.note,
  });

  final String name;
  final String? muscleGroup;
  final int sets;
  final int reps;
  final int restSeconds;
  final String? note;

  /// "3 × 12 · 60 s" (exercícios por tempo: "3 × 30 s" / "1 × 10 min").
  String get summary {
    final unit = name.contains('(segundos)') ? ' s' : (name.contains('(minutos)') ? ' min' : '');
    return '$sets × $reps$unit · $restSeconds s de descanso';
  }

  factory ProposedExercise.fromJson(Map<String, dynamic> json) => ProposedExercise(
        name: json['name'] as String? ?? 'Exercício',
        muscleGroup: json['muscleGroup'] as String?,
        sets: (json['sets'] as num).toInt(),
        reps: (json['reps'] as num).toInt(),
        restSeconds: (json['restSeconds'] as num).toInt(),
        note: (json['note'] as String?)?.trim().isEmpty ?? true ? null : json['note'] as String,
      );
}

class ProposedWorkout {
  const ProposedWorkout({required this.name, required this.exercises});

  final String name;
  final List<ProposedExercise> exercises;

  factory ProposedWorkout.fromJson(Map<String, dynamic> json) => ProposedWorkout(
        name: json['name'] as String? ?? 'Treino',
        exercises: [for (final e in json['exercises'] as List<dynamic>? ?? const []) ProposedExercise.fromJson(e as Map<String, dynamic>)],
      );
}

enum ProposalStatus { proposed, accepted, rejected, expired }

class WorkoutProposal {
  const WorkoutProposal({required this.id, required this.status, this.summary, required this.workouts, this.workoutIds = const []});

  final int id;
  final ProposalStatus status;
  final String? summary;
  final List<ProposedWorkout> workouts;
  final List<int> workoutIds;

  factory WorkoutProposal.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>? ?? const {};
    return WorkoutProposal(
      id: (json['id'] as num).toInt(),
      status: switch (json['status']) {
        'ACCEPTED' => ProposalStatus.accepted,
        'REJECTED' => ProposalStatus.rejected,
        'EXPIRED' => ProposalStatus.expired,
        _ => ProposalStatus.proposed,
      },
      summary: (content['summary'] as String?)?.trim().isEmpty ?? true ? null : content['summary'] as String,
      workouts: [for (final w in content['workouts'] as List<dynamic>? ?? const []) ProposedWorkout.fromJson(w as Map<String, dynamic>)],
      workoutIds: [for (final id in json['workoutIds'] as List<dynamic>? ?? const []) (id as num).toInt()],
    );
  }
}

/// Propostas de treino da IA: o aluno vê a prévia e só o aceite cria os treinos.
class AiWorkoutRepository {
  AiWorkoutRepository(this._dio);

  final Dio _dio;

  Future<ProposalEligibility> eligibility() => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/v1/ai/workout-proposals/eligibility');
        return ProposalEligibility.fromJson(response.data ?? const {});
      });

  Future<WorkoutProposal> propose({String? note}) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/ai/workout-proposals',
          data: {'note': (note == null || note.trim().isEmpty) ? null : note.trim()},
          // montar a proposta leva alguns segundos
          options: Options(receiveTimeout: const Duration(seconds: 90)),
        );
        return WorkoutProposal.fromJson(response.data!);
      });

  Future<WorkoutProposal> accept(int id) => _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/v1/ai/workout-proposals/$id/accept');
        return WorkoutProposal.fromJson(response.data!);
      });

  Future<void> reject(int id) => _guard(() => _dio.post<void>('/api/v1/ai/workout-proposals/$id/reject'));

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
