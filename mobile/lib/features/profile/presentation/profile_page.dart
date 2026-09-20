import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../auth/application/auth_controller.dart';
import '../../billing/presentation/subscription_card.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).value;
    if (profile == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.person), title: Text(profile.name), subtitle: const Text('Nome')),
              ListTile(leading: const Icon(Icons.email), title: Text(profile.email), subtitle: const Text('E-mail')),
              if (profile.goal != null && profile.goal!.isNotEmpty)
                ListTile(leading: const Icon(Icons.flag), title: Text(profile.goal!), subtitle: const Text('Objetivo')),
              if (profile.height != null)
                ListTile(leading: const Icon(Icons.height), title: Text('${profile.height} m'), subtitle: const Text('Altura')),
              if (profile.weight != null)
                ListTile(leading: const Icon(Icons.monitor_weight), title: Text(formatLoad(profile.weight)), subtitle: const Text('Peso')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SubscriptionCard(),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('logout'),
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Sair'),
        ),
      ],
    );
  }
}
