import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../../home/application/home_tab_provider.dart';
import '../../trainer/workouts/application/trainer_workouts_providers.dart';
import '../../workouts/application/workout_providers.dart';
import '../application/ai_workout_providers.dart';
import '../data/ai_workout_repository.dart';

/// Aviso fixo de toda proposta: a IA sugere, o aluno decide e respeita os próprios limites.
const proposalDisclaimer = 'Proposta gerada por IA a partir do seu perfil. Não substitui um profissional de educação física '
    'nem orientação médica. Comece com carga leve, mantenha a técnica e pare se sentir dor, tontura ou falta de ar.';

/// "Treino pela IA": pede uma proposta, mostra a prévia e só cria os treinos se o aluno aceitar.
class AiWorkoutPage extends ConsumerStatefulWidget {
  const AiWorkoutPage({super.key});

  @override
  ConsumerState<AiWorkoutPage> createState() => _AiWorkoutPageState();
}

class _AiWorkoutPageState extends ConsumerState<AiWorkoutPage> {
  final _note = TextEditingController();
  WorkoutProposal? _proposal;
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go('/');

  Future<void> _generate() async {
    final previous = _proposal;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final repo = ref.read(aiWorkoutRepositoryProvider);
      // pedir outra descarta a anterior (fica registrada como recusada)
      if (previous != null) await repo.reject(previous.id);
      final proposal = await repo.propose(note: _note.text);
      if (mounted) setState(() => _proposal = proposal);
    } catch (error) {
      if (mounted) setState(() => _error = messageOf(error));
    } finally {
      ref.invalidate(proposalEligibilityProvider);
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _accept() async {
    final proposal = _proposal!;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final accepted = await ref.read(aiWorkoutRepositoryProvider).accept(proposal.id);
      ref.invalidate(myWorkoutsProvider);
      ref.invalidate(trainerWorkoutsProvider);
      if (!mounted) return;
      final count = accepted.workoutIds.length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(count == 1 ? 'Treino criado! Ele já está na aba Treinos.' : '$count treinos criados! Eles já estão na aba Treinos.'),
      ));
      context.go('/');
    } catch (error) {
      if (mounted) setState(() => _error = messageOf(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _discard() async {
    final proposal = _proposal;
    if (proposal != null) {
      await runAction(context, () => ref.read(aiWorkoutRepositoryProvider).reject(proposal.id));
    }
    if (mounted) _back();
  }

  @override
  Widget build(BuildContext context) {
    final eligibility = ref.watch(proposalEligibilityProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: CircleIconButton(icon: LucideIcons.arrowLeft, tooltip: 'Voltar', onPressed: _back),
            ),
            const SizedBox(height: 12),
            Text('TREINO PELA IA', style: AppText.display(34)),
            Text('A IA monta uma proposta com base no seu perfil. Você confere e decide se usa.',
                style: AppText.body(size: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            if (_working && _proposal == null)
              const _Generating()
            else if (_proposal != null)
              ..._preview(_proposal!, eligibility.value)
            else
              eligibility.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                error: (error, _) => ErrorRetry(error: error, onRetry: () => ref.invalidate(proposalEligibilityProvider)),
                data: (e) => e.allowed ? _request(e) : _Blocked(eligibility: e),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, key: const Key('proposal-error'), style: AppText.body(size: 14, color: AppColors.danger)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _request(ProposalEligibility e) {
    final limit = e.monthlyLimit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('proposal-note'),
          controller: _note,
          maxLength: 300,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Alguma preferência? (opcional)',
            hintText: 'Ex.: mais foco em pernas, treinos curtos',
          ),
        ),
        const SizedBox(height: 8),
        PillButton(
          key: const Key('proposal-generate'),
          label: 'Gerar proposta',
          icon: LucideIcons.sparkles,
          onPressed: _working ? null : _generate,
        ),
        if (limit != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              e.pro ? 'Pro: ${e.usedThisMonth} de $limit propostas usadas este mês.' : 'Plano grátis: ${e.usedThisMonth} de $limit proposta usada este mês.',
              key: const Key('proposal-quota'),
              textAlign: TextAlign.center,
              style: AppText.body(size: 12.5, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }

  List<Widget> _preview(WorkoutProposal proposal, ProposalEligibility? eligibility) {
    final canRegenerate = eligibility?.allowed ?? false;
    return [
      if (proposal.summary != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(proposal.summary!, key: const Key('proposal-summary'), style: AppText.body(size: 15)),
        ),
      for (final workout in proposal.workouts) _WorkoutPreview(workout: workout),
      InfoAlert(kind: AlertKind.warn, icon: LucideIcons.shieldAlert, text: proposalDisclaimer),
      const SizedBox(height: 16),
      PillButton(
        key: const Key('proposal-accept'),
        label: _working ? 'Criando...' : (proposal.workouts.length == 1 ? 'Usar este treino' : 'Usar estes treinos'),
        icon: LucideIcons.check,
        onPressed: _working ? null : _accept,
      ),
      const SizedBox(height: 8),
      if (canRegenerate)
        PillButton(
          key: const Key('proposal-again'),
          label: 'Gerar outra',
          style: PillStyle.ghost,
          height: 46,
          onPressed: _working ? null : _generate,
        ),
      TextButton(key: const Key('proposal-discard'), onPressed: _working ? null : _discard, child: const Text('Descartar')),
    ];
  }
}

class _Generating extends StatelessWidget {
  const _Generating();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('proposal-generating'),
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Montando sua proposta...', style: AppText.body(size: 15, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _WorkoutPreview extends StatelessWidget {
  const _WorkoutPreview({required this.workout});

  final ProposedWorkout workout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workout.name.toUpperCase(), style: AppText.display(22)),
            const SizedBox(height: 8),
            for (var i = 0; i < workout.exercises.length; i++) ...[
              if (i > 0) const Divider(height: 16, color: AppColors.borderSubtle),
              Text('${i + 1}. ${workout.exercises[i].name}', style: AppText.body(size: 15, weight: FontWeight.w600)),
              Text(workout.exercises[i].summary, style: AppText.body(size: 13, color: AppColors.textSecondary)),
              if (workout.exercises[i].note != null)
                Text(workout.exercises[i].note!, style: AppText.body(size: 12.5, color: AppColors.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Não pode pedir agora: o motivo e o caminho para resolver.
class _Blocked extends ConsumerWidget {
  const _Blocked({required this.eligibility});

  final ProposalEligibility eligibility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = eligibility.reasonCode;
    final (String? label, VoidCallback? action) = switch (code) {
      'NO_PROFILE' || 'NO_SCREENING' || 'HEALTH_RISK' => (
          code == 'HEALTH_RISK' ? 'Rever a triagem de saúde' : 'Completar o perfil',
          () => context.push('/onboarding'),
        ),
      'FREE_LIMIT' => (
          'Conhecer o Pro',
          () {
            ref.read(homeTabProvider.notifier).select(HomeTab.profile);
            context.go('/');
          },
        ),
      _ => (null, null),
    };
    return Column(
      key: const Key('proposal-blocked'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoAlert(
          kind: AlertKind.warn,
          icon: code == 'HEALTH_RISK' ? LucideIcons.stethoscope : LucideIcons.info,
          text: eligibility.reason ?? 'Não é possível montar uma proposta agora.',
        ),
        if (label != null) ...[
          const SizedBox(height: 14),
          PillButton(key: const Key('proposal-blocked-action'), label: label, style: PillStyle.ghost, height: 46, onPressed: action),
        ],
      ],
    );
  }
}
