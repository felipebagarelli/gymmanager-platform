import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/hub_repository.dart';

final hubRepositoryProvider = Provider<HubRepository>((ref) => HubRepository(ref.watch(dioProvider)));

final trainerDetailProvider =
    FutureProvider.autoDispose.family<TrainerDetail, int>((ref, id) => ref.watch(hubRepositoryProvider).detail(id));

final myPublicProfileProvider =
    FutureProvider.autoDispose<PublicProfile>((ref) => ref.watch(hubRepositoryProvider).myPublicProfile());
