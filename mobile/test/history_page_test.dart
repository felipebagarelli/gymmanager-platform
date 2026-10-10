import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/theme/app_colors.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/home/application/home_tab_provider.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/sessions/domain/workout_session.dart';
import 'package:gymmanager_mobile/features/sessions/presentation/history_page.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';

import 'support/fake_repositories.dart';
import 'support/fakes.dart';

final _now = DateTime(2026, 10, 10, 12); // sábado

WorkoutSession _session(int id, DateTime start, List<Performance> sets) => WorkoutSession(
      id: id,
      workoutId: 10,
      startedAt: start,
      finishedAt: start.add(const Duration(minutes: 45)),
      performances: sets,
    );

// FakeWorkoutRepository: item 100 = Supino, 101 = Agachamento
Performance _set(int id, int reps, double? load, {int item = 100, Effort? effort}) =>
    Performance(id: id, workoutExerciseId: item, setNumber: id, reps: reps, loadKg: load, effort: effort);

List<Override> _overrides(List<WorkoutSession> sessions) => [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage(StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)))),
      ),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      sessionRepositoryProvider.overrideWithValue(FakeSessionRepository(initial: sessions)),
      workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
      clockProvider.overrideWithValue(() => _now),
    ];

class _FixedSubTab extends HistorySubTabController {
  _FixedSubTab(this.initial);
  final int initial;
  @override
  int build() => initial;
}

Widget _app(List<WorkoutSession> sessions, {int subTab = 0}) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        ..._overrides(sessions),
        if (subTab != 0) historySubTabProvider.overrideWith(() => _FixedSubTab(subTab)),
      ],
      child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: HistoryPage())),
    );

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Color _dayColor(WidgetTester tester, int day) =>
    (tester.widget<Container>(find.byKey(Key('day-$day'))).decoration! as BoxDecoration).color!;

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

Finder _in(String key, Finder matching) => find.descendant(of: find.byKey(Key(key)), matching: matching);

void main() {
  final october = [
    _session(1, DateTime(2026, 10, 5, 9), [_set(1, 10, 40)]), // 400 kg (segunda)
    _session(2, DateTime(2026, 10, 8, 9), [_set(2, 10, 50, effort: Effort.hard), _set(3, 10, 50)]), // 1000 kg
  ];

  group('aba Sessões', () {
    testWidgets('calendário do mês, intensidade, números e lista', (tester) async {
      await _pump(tester, _app(october));

      expect(find.text('HISTÓRICO'), findsOneWidget);
      expect(find.text('Outubro 2026'), findsOneWidget);
      expect(find.text('2 treinos'), findsOneWidget);
      expect(_dayColor(tester, 8), AppColors.volt); // maior volume do mês
      expect(_dayColor(tester, 5), AppColors.mix(AppColors.volt, 0.62, AppColors.elevated)); // 40% do maior
      expect(_dayColor(tester, 6), AppColors.elevated); // sem treino
      expect(_in('kpi-month-volume', find.text('1,4')), findsOneWidget);
      expect(_in('kpi-month-volume', find.text('t')), findsOneWidget);
      expect(_in('kpi-streak', find.text('1')), findsOneWidget);
      expect(find.byKey(const Key('session-1')), findsOneWidget);
      expect(find.byKey(const Key('session-2')), findsOneWidget);
      expect(_in('session-2', find.text('Treino A')), findsOneWidget);
      expect(_in('session-2', find.text('45 min · 2 séries · 1 t')), findsOneWidget);
    });

    testWidgets('navega entre os meses e não passa do mês atual', (tester) async {
      await _pump(tester, _app(october));
      expect(tester.widget<IconButton>(_in('month-next', find.byType(IconButton))).onPressed, isNull);

      await tester.tap(find.byKey(const Key('month-previous')));
      await tester.pumpAndSettle();
      expect(find.text('Setembro 2026'), findsOneWidget);
      expect(find.text('Nenhum treino em setembro 2026.'), findsOneWidget);
      expect(find.byKey(const Key('session-1')), findsNothing);

      await tester.tap(find.byKey(const Key('month-next')));
      await tester.pumpAndSettle();
      expect(find.text('Outubro 2026'), findsOneWidget);
      expect(find.byKey(const Key('session-1')), findsOneWidget);
    });

    testWidgets('tocar numa sessão abre o detalhe com as séries por exercício', (tester) async {
      await _pump(tester, _app(october));

      await tester.tap(find.byKey(const Key('session-2')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('session-detail')), findsOneWidget);
      expect(_in('session-detail', find.text('TREINO A')), findsOneWidget);
      expect(_in('session-detail', find.text('SUPINO')), findsOneWidget); // rótulo em caixa alta
      expect(_in('session-detail', find.text('10 reps × 50 kg')), findsNWidgets(2));
      expect(_in('session-detail', find.text('Difícil')), findsOneWidget);
      expect(_in('session-detail', find.text('45 min')), findsOneWidget);
    });

    testWidgets('sem nenhum treino, mostra o estado vazio', (tester) async {
      await _pump(tester, _app(const []));
      expect(find.text('Você ainda não executou nenhum treino.'), findsOneWidget);
    });
  });

  group('aba Evolução', () {
    final two = [
      _session(1, DateTime(2026, 9, 21, 9), [_set(1, 10, 40)]),
      _session(2, DateTime(2026, 10, 5, 9), [_set(2, 10, 50)]),
    ];

    testWidgets('troca de aba pelo seletor e mostra carga, ganho, recorde e treinos do mês', (tester) async {
      await _pump(tester, _app(two));
      expect(find.byKey(const Key('load-chart')), findsNothing); // aba Sessões ativa

      await tester.tap(find.byKey(const Key('history-tab-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('exercise-chip-Supino')), findsOneWidget);
      expect(find.byKey(const Key('load-chart')), findsOneWidget);
      expect(_text(tester, 'load-readout'), '50');
      expect(_text(tester, 'load-readout-date'), 'semana de 5/10');
      expect(find.text('+25% em 2 sem'), findsOneWidget);
      expect(_text(tester, 'record-value'), '50 kg');
      expect(_text(tester, 'month-count'), '1');
    });

    testWidgets('abre direto na Evolução quando o provedor pede (botão "Ver evolução")', (tester) async {
      await _pump(tester, _app(two, subTab: 1));
      expect(find.byKey(const Key('load-chart')), findsOneWidget);
    });

    testWidgets('barras de volume são tocáveis e atualizam a leitura', (tester) async {
      await _pump(tester, _app(two, subTab: 1));
      expect(_text(tester, 'volume-readout'), '5/10 · 500 kg');

      await tester.tap(find.byKey(const Key('volume-bar-5')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'volume-readout'), '21/9 · 400 kg');
    });

    testWidgets('com um único ponto, mostra o ponto e a mensagem em vez de uma linha', (tester) async {
      await _pump(tester, _app([_session(1, DateTime(2026, 10, 5, 9), [_set(1, 10, 40)])], subTab: 1));

      expect(find.byKey(const Key('load-chart')), findsOneWidget);
      expect(find.text('Registre mais um treino para ver sua evolução.'), findsOneWidget);
      expect(find.byKey(const Key('progress-delta')), findsNothing);
    });

    testWidgets('exercício sem carga informada explica em vez de desenhar gráfico', (tester) async {
      await _pump(tester, _app([_session(1, DateTime(2026, 10, 5, 9), [_set(1, 12, null, item: 101)])], subTab: 1));

      expect(find.byKey(const Key('no-load-data')), findsOneWidget);
      expect(find.byKey(const Key('load-chart')), findsNothing);
      expect(_text(tester, 'record-value'), '—');
    });

    testWidgets('trocar o exercício pelos chips muda o gráfico', (tester) async {
      await _pump(
        tester,
        _app([
          _session(1, DateTime(2026, 9, 21, 9), [_set(1, 10, 40), _set(2, 12, 60, item: 101)]),
          _session(2, DateTime(2026, 10, 5, 9), [_set(3, 10, 50), _set(4, 12, 70, item: 101)]),
        ], subTab: 1),
      );
      // ordem alfabética: abre no primeiro
      expect(find.byKey(const Key('progress-Agachamento')), findsOneWidget);
      expect(_text(tester, 'load-readout'), '70');

      await tester.tap(find.byKey(const Key('exercise-chip-Supino')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('progress-Supino')), findsOneWidget);
      expect(_text(tester, 'load-readout'), '50');
    });

    testWidgets('sem sessões finalizadas, mostra o estado vazio', (tester) async {
      await _pump(tester, _app(const [], subTab: 1));
      expect(find.textContaining('Finalize alguns treinos'), findsOneWidget);
    });
  });
}
