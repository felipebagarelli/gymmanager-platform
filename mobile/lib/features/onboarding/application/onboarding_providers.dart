import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/onboarding_repository.dart';
import '../domain/onboarding.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) => OnboardingRepository(ref.watch(dioProvider)));

/// Onboarding do aluno logado (null para quem não é aluno).
final onboardingStatusProvider = FutureProvider<OnboardingStatus?>((ref) async {
  if (ref.watch(currentStudentProvider) == null) return null;
  return ref.watch(onboardingRepositoryProvider).status();
});

/// Aluno sem personal que ainda não fez o onboarding: o app leva para ele antes de tudo.
/// Se a consulta falhar, não trava o app (a pessoa continua podendo registrar treinos).
final needsOnboardingProvider = Provider<bool>((ref) {
  final student = ref.watch(currentStudentProvider);
  if (student == null || student.hasTrainer) return false;
  final status = ref.watch(onboardingStatusProvider).value;
  return status != null && !status.completed;
});
