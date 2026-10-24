import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/widgets/app_card.dart';
import '../../account/application/account_providers.dart';
import '../../account/presentation/account_actions.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/student_profile.dart';
import '../../billing/presentation/subscription_card.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../../platform_plan/presentation/platform_plan_card.dart';
import '../../chat/application/chat_providers.dart';
import '../../sessions/application/evolution_providers.dart';
import '../../sessions/application/session_providers.dart';
import '../../sessions/domain/history_stats.dart';
import '../../sessions/domain/training_stats.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentStudentProvider);
    if (profile == null) return const SizedBox.shrink();
    final trainer = ref.watch(chatSummaryProvider).value?.trainerName;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(kScreenPadding, 16, kScreenPadding, 24),
        children: [
          Row(
            children: [
              InitialsAvatar(name: profile.name, size: 68),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name.toUpperCase(), key: const Key('profile-name'), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.display(32)),
                    Text(trainer == null ? 'Aluno' : 'Aluno de $trainer',
                        style: AppText.body(size: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _Stats(),
          const SizedBox(height: 14),
          // sem personal: plano da plataforma; com personal: a mensalidade dele
          if (profile.hasTrainer) const SubscriptionCard() else const PlatformPlanCard(),
          const SizedBox(height: 14),
          AppCard(
            padding: EdgeInsets.zero,
            radius: 18,
            child: Column(
              children: [
                _MenuRow(
                  key: const Key('menu-personal-data'),
                  icon: LucideIcons.user,
                  label: 'Dados pessoais',
                  onTap: () => _showPersonalData(context, ref, profile),
                ),
                if (!profile.hasTrainer)
                  _MenuRow(
                    key: const Key('menu-training-profile'),
                    icon: LucideIcons.clipboardList,
                    label: 'Perfil de treino e saúde',
                    onTap: () => context.push('/onboarding'),
                  ),
                const _ShareHealthRow(),
                const _MenuRow(icon: LucideIcons.bell, label: 'Notificações', soon: true),
                _MenuRow(
                  key: const Key('menu-legal'),
                  icon: LucideIcons.shieldCheck,
                  label: 'Privacidade e termos',
                  onTap: () => showLegalDocuments(context, ref),
                ),
                _MenuRow(
                  key: const Key('menu-delete-account'),
                  icon: LucideIcons.trash2,
                  label: 'Excluir conta',
                  danger: true,
                  onTap: () => deleteMyAccount(context, ref, trainer: false),
                ),
                _MenuRow(
                  key: const Key('logout'),
                  icon: LucideIcons.logOut,
                  label: 'Sair',
                  danger: true,
                  onTap: () => ref.read(authControllerProvider.notifier).logout(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Treinos feitos, semanas seguidas e recordes: tudo calculado do histórico do aluno.
class _Stats extends ConsumerWidget {
  const _Stats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historyProvider).value;
    final progress = ref.watch(evolutionProvider).value;
    final now = ref.watch(clockProvider)();
    final workouts = sessions == null ? null : finishedSessions(sessions).length;
    final weeks = sessions == null ? null : TrainingStats.from(sessions, now: now).streakWeeks;
    final records = progress == null ? null : recordCount(progress);

    return Row(
      children: [
        Expanded(child: _Stat(key: const Key('stat-workouts'), value: workouts, label: 'Treinos')),
        const SizedBox(width: 10),
        Expanded(child: _Stat(key: const Key('stat-weeks'), value: weeks, label: 'Semanas')),
        const SizedBox(width: 10),
        Expanded(child: _Stat(key: const Key('stat-records'), value: records, label: 'Recordes')),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.value, required this.label});

  final int? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value?.toString() ?? '—', style: AppText.display(36)),
          LabelText(label),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({super.key, required this.icon, required this.label, this.onTap, this.danger = false, this.soon = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  /// Recurso que ainda não existe no app: aparece desabilitado com a etiqueta "Em breve".
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : (soon ? AppColors.textMuted : AppColors.textPrimary);
    return Semantics(
      button: !soon,
      enabled: !soon,
      label: soon ? '$label, em breve' : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: soon ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderSubtle))),
          child: Row(
            children: [
              Icon(icon, size: 20, color: danger ? AppColors.danger : AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppText.body(size: 15.5, weight: FontWeight.w500, color: color))),
              if (soon)
                const TagChip('Em breve')
              else if (!danger)
                const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Mostrar minha triagem ao personal": o aluno decide (LGPD: dado de saúde só com consentimento).
class _ShareHealthRow extends ConsumerWidget {
  const _ShareHealthRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(onboardingStatusProvider).value;
    if (status == null) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderSubtle))),
      child: Row(
        children: [
          const Icon(LucideIcons.heartPulse, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mostrar minha triagem ao personal', style: AppText.body(size: 15.5, weight: FontWeight.w500)),
                Text('Respostas de saúde e perfil de treino', style: AppText.body(size: 12.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          Switch(
            key: const Key('share-health'),
            value: status.shareWithTrainer,
            onChanged: (share) async {
              final ok = await runAction(context, () => ref.read(onboardingRepositoryProvider).setSharing(share));
              if (ok) ref.invalidate(onboardingStatusProvider);
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _editPersonalData(BuildContext context, WidgetRef ref, StudentProfile profile) async {
  final values = await showEditFieldsSheet(
    context,
    title: 'Corrigir dados',
    fields: [
      EditField('name', 'Nome', profile.name, required: true),
      EditField('phone', 'Telefone', profile.phone ?? '', keyboard: TextInputType.phone),
      EditField('height', 'Altura (m)', profile.height == null ? '' : formatNumber(profile.height!),
          keyboard: const TextInputType.numberWithOptions(decimal: true), helper: 'Ex.: 1,72'),
      EditField('weight', 'Peso (kg)', profile.weight == null ? '' : formatNumber(profile.weight!),
          keyboard: const TextInputType.numberWithOptions(decimal: true)),
    ],
    validate: (v) => {
      'height': v['height']!.isEmpty || (parseDecimal(v['height']!) ?? 0) >= 0.9 && (parseDecimal(v['height']!) ?? 0) <= 2.5
          ? null
          : 'Altura em metros, entre 0,9 e 2,5.',
      'weight': v['weight']!.isEmpty || (parseDecimal(v['weight']!) ?? 0) >= 25 && (parseDecimal(v['weight']!) ?? 0) <= 350
          ? null
          : 'Peso em kg, entre 25 e 350.',
    },
  );
  if (values == null || !context.mounted) return;
  final ok = await runAction(
    context,
    () => ref.read(accountRepositoryProvider).updateStudentData(
          name: values['name']!,
          phone: values['phone']!.isEmpty ? null : values['phone'],
          height: parseDecimal(values['height']!),
          weight: parseDecimal(values['weight']!),
        ),
  );
  if (!ok) return;
  await ref.read(authControllerProvider.notifier).refreshUser();
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados salvos')));
}

void _showPersonalData(BuildContext context, WidgetRef ref, StudentProfile profile) {
  final goal = profile.goal;
  final rows = <(String, String)>[
    ('Nome', profile.name),
    ('E-mail', profile.email),
    if (profile.phone != null && profile.phone!.isNotEmpty) ('Telefone', profile.phone!),
    if (goal != null && goal.isNotEmpty) ('Objetivo', goal),
    if (profile.height != null) ('Altura', '${formatNumber(profile.height!)} m'),
    if (profile.weight != null) ('Peso', formatLoad(profile.weight)),
  ];
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.elevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetContext) => SingleChildScrollView(
      key: const Key('personal-data'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DADOS PESSOAIS', style: AppText.display(30)),
          const SizedBox(height: 14),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabelText(label),
                  const SizedBox(height: 2),
                  Text(value, style: AppText.body(size: 16, weight: FontWeight.w500)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('edit-personal-data'),
            icon: const Icon(LucideIcons.pencil, size: 18),
            label: const Text('Corrigir meus dados'),
            onPressed: () {
              Navigator.of(sheetContext).pop();
              // contexto da página: o da folha deixa de existir ao fechar
              _editPersonalData(context, ref, profile);
            },
          ),
          const SizedBox(height: 8),
          Text('O e-mail é o seu login e não muda por aqui.', style: AppText.body(size: 13, color: AppColors.textMuted)),
        ],
      ),
    ),
  );
}
