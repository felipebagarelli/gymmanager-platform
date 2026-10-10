import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/core/widgets/pill_button.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';
import 'package:gymmanager_mobile/features/workouts/presentation/workout_detail_page.dart';

import 'support/fake_repositories.dart';
import 'support/fakes.dart';

/// O histórico só chega quando o teste libera: simula a rede lenta.
class _SlowHistoryRepository extends FakeSessionRepository {
  _SlowHistoryRepository();

  final gate = Completer<void>();

  @override
  Future<List<WorkoutSession>> history(int studentId) async {
    await gate.future;
    return super.history(studentId);
  }
}

Widget _app(FakeSessionRepository sessions) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage(StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)))),
        ),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        sessionRepositoryProvider.overrideWithValue(sessions),
      ],
      child: MaterialApp(theme: AppTheme.dark(), home: const WorkoutDetailPage(workoutId: 10)),
    );

PillButton _button(WidgetTester tester) => tester.widget<PillButton>(find.byKey(const Key('open-execution')));

void main() {
  testWidgets('enquanto não sabe se já há sessão aberta, "Iniciar treino" fica desabilitado', (tester) async {
    final repository = _SlowHistoryRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('open-execution')), findsOneWidget);
    expect(_button(tester).onPressed, isNull);

    repository.gate.complete();
    await tester.pumpAndSettle();

    expect(_button(tester).onPressed, isNotNull);
    expect(_button(tester).label, 'Iniciar treino');
  });

  testWidgets('com sessão em andamento, oferece "Continuar treino" (sem iniciar outra)', (tester) async {
    final repository = _SlowHistoryRepository();
    await repository.start(10);
    await tester.pumpWidget(_app(repository));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_button(tester).onPressed, isNull);

    repository.gate.complete();
    await tester.pumpAndSettle();

    expect(_button(tester).label, 'Continuar treino');
    expect(_button(tester).onPressed, isNotNull);
    expect(repository.sessions, hasLength(1));
  });
}
