import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmanager_mobile/core/errors/app_exception.dart';
import 'package:gymmanager_mobile/features/billing/application/billing_providers.dart';
import 'package:gymmanager_mobile/features/billing/data/billing_repository.dart';
import 'package:gymmanager_mobile/features/billing/domain/billing.dart';
import 'package:gymmanager_mobile/features/billing/presentation/subscription_card.dart';

class FakeBillingRepository extends BillingRepository {
  FakeBillingRepository({this.subscription, this.plans = const []}) : super(Dio());

  Subscription? subscription;
  List<Plan> plans;
  AppException? subscribeError;
  bool cancelled = false;
  final List<int> subscribed = [];

  @override
  Future<List<Plan>> availablePlans() async => plans;

  @override
  Future<Subscription?> mySubscription() async => cancelled ? null : subscription;

  @override
  Future<String> subscribe(int planId) async {
    if (subscribeError != null) throw subscribeError!;
    subscribed.add(planId);
    return 'https://checkout.example/pay';
  }

  @override
  Future<void> cancel() async => cancelled = true;
}

Widget _app(FakeBillingRepository repo, {List<String>? opened}) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        billingRepositoryProvider.overrideWithValue(repo),
        urlOpenerProvider.overrideWithValue((url) async {
          opened?.add(url);
          return true;
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SubscriptionCard()))),
    );

const _plan = Plan(id: 3, name: 'Mensal', priceCents: 15000, description: '3x por semana');

Subscription _sub(SubscriptionStatus status) =>
    Subscription(id: 1, status: status, planName: 'Mensal', priceCents: 15000);

void main() {
  test('parse e formatacao de preco', () {
    final sub = Subscription.fromJson({
      'id': 1,
      'status': 'PAST_DUE',
      'planName': 'Mensal',
      'priceCents': 15050,
      'currentPeriodEnd': '2026-10-01T00:00:00',
    });
    expect(sub.status, SubscriptionStatus.pastDue);
    expect(sub.currentPeriodEnd!.month, 10);
    expect(formatPrice(15050), 'R\$ 150,50');
    expect(formatPrice(100), 'R\$ 1,00');
  });

  testWidgets('sem assinatura lista os planos e abre o checkout ao assinar', (tester) async {
    final opened = <String>[];
    final repo = FakeBillingRepository(plans: [_plan]);
    await tester.pumpWidget(_app(repo, opened: opened));
    await tester.pumpAndSettle();

    expect(find.text('Mensal'), findsOneWidget);
    expect(find.textContaining('R\$ 150,00/mês'), findsOneWidget);

    await tester.tap(find.byKey(const Key('subscribe-3')));
    await tester.pumpAndSettle();

    expect(repo.subscribed, [3]);
    expect(opened, ['https://checkout.example/pay']);
  });

  testWidgets('sem planos publicados mostra aviso', (tester) async {
    await tester.pumpWidget(_app(FakeBillingRepository()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('no-plans')), findsOneWidget);
  });

  testWidgets('erro ao assinar aparece como mensagem', (tester) async {
    final repo = FakeBillingRepository(plans: [_plan])
      ..subscribeError = AppException('Seu personal ainda não habilitou o recebimento de pagamentos.');
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('subscribe-3')));
    await tester.pumpAndSettle();

    expect(find.text('Seu personal ainda não habilitou o recebimento de pagamentos.'), findsOneWidget);
  });

  testWidgets('assinatura em atraso mostra o aviso de bloqueio', (tester) async {
    await tester.pumpWidget(_app(FakeBillingRepository(subscription: _sub(SubscriptionStatus.pastDue))));
    await tester.pumpAndSettle();

    expect(find.text('Em atraso'), findsOneWidget);
    expect(find.byKey(const Key('overdue-notice')), findsOneWidget);
  });

  testWidgets('assinatura em dia nao mostra aviso e permite cancelar', (tester) async {
    final repo = FakeBillingRepository(subscription: _sub(SubscriptionStatus.active));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Em dia'), findsOneWidget);
    expect(find.byKey(const Key('overdue-notice')), findsNothing);

    await tester.tap(find.byKey(const Key('cancel-subscription')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();

    expect(repo.cancelled, isTrue);
    expect(find.byKey(const Key('subscription-status')), findsNothing);
  });
}
