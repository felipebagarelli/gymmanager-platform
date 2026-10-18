import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/platform_plan_repository.dart';

final platformPlanRepositoryProvider =
    Provider<PlatformPlanRepository>((ref) => PlatformPlanRepository(ref.watch(dioProvider)));

/// Plano da plataforma do aluno sem personal (null para os demais).
final platformPlanProvider = FutureProvider<PlatformPlanStatus?>((ref) async {
  final student = ref.watch(currentStudentProvider);
  if (student == null || student.hasTrainer) return null;
  return ref.watch(platformPlanRepositoryProvider).status();
});
