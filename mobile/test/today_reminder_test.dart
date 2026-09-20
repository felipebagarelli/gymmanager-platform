import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';
import 'package:gymmanager_mobile/features/workouts/presentation/my_workouts_page.dart';

import 'support/fake_repositories.dart';
import 'support/fakes.dart';

List<Override> _overrides({List<WorkoutSession>? sessions}) => [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage(StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)))),
      ),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      sessionRepositoryProvider.overrideWithValue(FakeSessionRepository(initial: sessions)),
      workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
    ];

Widget _app({List<WorkoutSession>? sessions}) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: _overrides(sessions: sessions),
      child: const MaterialApp(home: Scaffold(body: MyWorkoutsPage())),
    );

void main() {
  testWidgets('mostra o lembrete quando o aluno ainda nao treinou hoje', (tester) async {
    await tester.pumpWidget(_app(sessions: [
      WorkoutSession(id: 1, workoutId: 10, startedAt: DateTime.now().subtract(const Duration(days: 3))),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today-reminder')), findsOneWidget);
  });

  testWidgets('esconde o lembrete quando ja ha uma sessao iniciada hoje', (tester) async {
    await tester.pumpWidget(_app(sessions: [
      WorkoutSession(id: 1, workoutId: 10, startedAt: DateTime.now()),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today-reminder')), findsNothing);
  });

  testWidgets('sem nenhuma sessao ainda, mostra o lembrete', (tester) async {
    await tester.pumpWidget(_app(sessions: []));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today-reminder')), findsOneWidget);
  });
}
