import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/ai_workout_repository.dart';

final aiWorkoutRepositoryProvider = Provider<AiWorkoutRepository>((ref) => AiWorkoutRepository(ref.watch(dioProvider)));

final proposalEligibilityProvider =
    FutureProvider.autoDispose<ProposalEligibility>((ref) => ref.watch(aiWorkoutRepositoryProvider).eligibility());
