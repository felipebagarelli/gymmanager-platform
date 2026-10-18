import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/providers.dart';
import 'package:gymmanager_mobile/core/routing/app_router.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/core/theme/app_theme.dart';
import 'package:gymmanager_mobile/features/auth/application/auth_controller.dart';
import 'package:gymmanager_mobile/features/auth/domain/student_profile.dart';
import 'package:gymmanager_mobile/features/billing/application/billing_providers.dart';
import 'package:gymmanager_mobile/features/chat/application/chat_providers.dart';
import 'package:gymmanager_mobile/features/chat/domain/chat.dart';
import 'package:gymmanager_mobile/features/hub/application/hub_providers.dart';
import 'package:gymmanager_mobile/features/hub/data/hub_repository.dart';
import 'package:gymmanager_mobile/features/hub/presentation/public_profile_page.dart';
import 'package:gymmanager_mobile/features/onboarding/application/onboarding_providers.dart';
import 'package:gymmanager_mobile/features/sessions/application/session_providers.dart';
import 'package:gymmanager_mobile/features/workouts/application/workout_providers.dart';

import 'onboarding_test.dart' show FakeOnboardingRepository;
import 'support/fake_chat.dart';
import 'support/fake_hub.dart';
import 'support/fake_repositories.dart';
import 'support/fakes.dart';

class _NoConversation extends FakeChatRepository {
  @override
  Future<List<ConversationSummary>> conversations() async => const [];
}

const _independent = StudentProfile(id: 9, email: 'ana@example.com', name: 'Ana Independente', hasTrainer: false);

Widget _app(FakeHubRepository hub, {String role = 'STUDENT', List<String>? opened}) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(
          StoredSession(token: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)), role: role),
        )),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(role: role, profile: _independent)),
        onboardingRepositoryProvider.overrideWithValue(FakeOnboardingRepository()),
        needsOnboardingProvider.overrideWithValue(false),
        hubRepositoryProvider.overrideWithValue(hub),
        chatRepositoryProvider.overrideWithValue(_NoConversation()),
        chatSummaryIntervalProvider.overrideWithValue(const Duration(hours: 1)),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        urlOpenerProvider.overrideWithValue((url) async {
          opened?.add(url);
          return true;
        }),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 18, 12)),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(theme: AppTheme.dark(), routerConfig: ref.watch(routerProvider)),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('aluno sem personal busca, filtra e vê o perfil com os planos', (tester) async {
    final hub = FakeHubRepository();
    await _pump(tester, _app(hub));
    await _tap(tester, find.text('Mensagens'));

    expect(find.text('ENCONTRE UM PERSONAL'), findsOneWidget);
    expect(find.byKey(const Key('hub-trainer-5')), findsOneWidget);
    expect(find.byKey(const Key('hub-trainer-6')), findsOneWidget);
    expect(find.text('A partir de R\$ 150,00/mês'), findsOneWidget);
    expect(find.text('São Paulo/SP · Online'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('hub-online')));
    expect(find.byKey(const Key('hub-trainer-6')), findsNothing);
    await _tap(tester, find.byKey(const Key('hub-online')));

    await tester.enterText(find.byKey(const Key('hub-search')), 'campinas');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hub-trainer-5')), findsNothing);
    expect(find.byKey(const Key('hub-trainer-6')), findsOneWidget);

    await _tap(tester, find.byKey(const Key('hub-trainer-6')));
    expect(find.text('BIA TREINOS'), findsOneWidget);
    expect(find.text('Emagrecimento'), findsOneWidget);
    expect(find.textContaining('8 anos de experiência'), findsOneWidget);
    expect(find.byKey(const Key('hub-plan-60')), findsOneWidget);
    await _close(tester);
  });

  testWidgets('assinar abre o pagamento; o vínculo só começa depois', (tester) async {
    final hub = FakeHubRepository();
    final opened = <String>[];
    await _pump(tester, _app(hub, opened: opened));
    await _tap(tester, find.text('Mensagens'));
    await _tap(tester, find.byKey(const Key('hub-trainer-5')));

    expect(find.byKey(const Key('hub-hire-note')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('hub-hire-50')));

    expect(hub.calls, contains('hire:5:50'));
    expect(opened, ['https://checkout.stripe.test/hire']);
    await _close(tester);
  });

  testWidgets('personal edita o perfil público e vê o que falta para aparecer', (tester) async {
    final hub = FakeHubRepository();
    await _pump(tester, _app(hub, role: 'TRAINER'));
    await _tap(tester, find.text('Perfil'));
    await _tap(tester, find.byKey(const Key('open-public-profile')));

    expect(find.byType(PublicProfilePage), findsOneWidget);
    expect(find.byKey(const Key('public-missing')), findsOneWidget);
    expect(find.text('Escreva uma chamada curta.'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('public-listed')));
    await tester.enterText(find.byKey(const Key('public-headline')), 'Hipertrofia online');
    await tester.enterText(find.byKey(const Key('public-state')), 'sp');
    await _tap(tester, find.byKey(const Key('public-specialty-hypertrophy')));
    await _tap(tester, find.byKey(const Key('public-save')));

    expect(hub.calls.last, 'save:true:Hipertrofia online:sp:HYPERTROPHY');
    expect(find.text('Perfil salvo. Você já aparece no hub.'), findsOneWidget);
    expect(find.text('Você aparece na busca de personais.'), findsOneWidget);
    await _close(tester);
  });

  test('vínculo pendente de pagamento não conta como ter personal', () {
    expect(StudentProfile.fromJson({'id': 1, 'email': 'a@b.c', 'name': 'A', 'status': 'INVITED'}).hasTrainer, isFalse);
    expect(StudentProfile.fromJson({'id': 1, 'email': 'a@b.c', 'name': 'A', 'status': 'PAUSED'}).hasTrainer, isTrue);
    expect(trainerPlace(city: null, state: null, online: true, inPerson: true), 'Online e presencial');
    expect(TrainerSpecialty.parse(['SENIORS', 'X']), [TrainerSpecialty.seniors]);
  });
}
