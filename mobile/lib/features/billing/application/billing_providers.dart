import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../data/billing_repository.dart';
import '../domain/billing.dart';

final billingRepositoryProvider =
    Provider<BillingRepository>((ref) => BillingRepository(ref.watch(dioProvider)));

/// Abre uma URL fora do app (checkout). Sobrescrevivel em testes.
final urlOpenerProvider = Provider<Future<bool> Function(String url)>(
  (ref) => (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
);

final mySubscriptionProvider = FutureProvider.autoDispose<Subscription?>(
  (ref) => ref.watch(billingRepositoryProvider).mySubscription(),
);

final availablePlansProvider = FutureProvider.autoDispose<List<Plan>>(
  (ref) => ref.watch(billingRepositoryProvider).availablePlans(),
);
