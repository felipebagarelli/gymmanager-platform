import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/application/auth_controller.dart';

/// Perfil do personal: identificação e sair.
class TrainerProfilePage extends ConsumerWidget {
  const TrainerProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainer = ref.watch(currentTrainerProvider);
    if (trainer == null) return const SizedBox.shrink();
    final phone = trainer.phone;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(kScreenPadding, 16, kScreenPadding, 24),
        children: [
          Row(
            children: [
              InitialsAvatar(name: trainer.displayName, size: 68),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trainer.displayName.toUpperCase(),
                        key: const Key('trainer-name'), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.display(32)),
                    Text('Personal', style: AppText.body(size: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AppCard(
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(label: 'E-mail', value: trainer.email),
                if (phone != null && phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Field(label: 'Telefone', value: phone),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            key: const Key('open-public-profile'),
            radius: 18,
            padding: const EdgeInsets.all(14),
            onTap: () => context.push('/trainer/public-profile'),
            child: Row(
              children: [
                const Icon(LucideIcons.store, size: 22, color: AppColors.volt),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Perfil no hub', style: AppText.body(size: 15.5, weight: FontWeight.w600)),
                      Text('Apareça para alunos que procuram um personal', style: AppText.body(size: 13, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: EdgeInsets.zero,
            radius: 18,
            child: InkWell(
              key: const Key('trainer-logout'),
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(LucideIcons.logOut, size: 20, color: AppColors.danger),
                    const SizedBox(width: 12),
                    Text('Sair', style: AppText.body(size: 15.5, weight: FontWeight.w500, color: AppColors.danger)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabelText(label),
        const SizedBox(height: 2),
        Text(value, style: AppText.body(size: 16, weight: FontWeight.w500)),
      ],
    );
  }
}
