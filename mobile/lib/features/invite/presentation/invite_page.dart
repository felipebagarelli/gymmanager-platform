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
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../../billing/application/billing_providers.dart';
import '../../billing/domain/billing.dart';
import '../application/invite_providers.dart';

/// Convite de um plano (link do personal): o aluno vê o plano e assina pelo app.
class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key, required this.code});

  final String code;

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  late final AppLifecycleListener _lifecycle;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // o convite já foi aberto: não precisa mais trazer de volta para cá
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(pendingInviteProvider.notifier).set(null);
    });
    // o pagamento acontece no navegador: ao voltar, confere se o vínculo já começou
    _lifecycle = AppLifecycleListener(onResume: _checkHired);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _checkHired() async {
    await ref.read(authControllerProvider.notifier).refreshUser();
    if (!mounted) return;
    if (ref.read(currentStudentProvider)?.hasTrainer ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pagamento confirmado! Agora você treina com seu personal.')));
      context.go('/');
    }
  }

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    await runAction(context, () async {
      final url = await ref.read(inviteRepositoryProvider).accept(widget.code);
      final opened = await ref.read(urlOpenerProvider)(url);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir a página de pagamento.')));
      }
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final invite = ref.watch(invitePreviewProvider(widget.code));
    final hasTrainer = ref.watch(currentStudentProvider)?.hasTrainer ?? false;

    return Scaffold(
      body: SafeArea(
        child: invite.when(
          loading: () => const SkeletonList(heights: [56, 120, 160]),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(kScreenPadding),
                child: CircleIconButton(icon: LucideIcons.arrowLeft, tooltip: 'Voltar', onPressed: () => context.go('/')),
              ),
              Expanded(
                child: EmptyState(key: const Key('invite-error'), icon: LucideIcons.link2Off, message: messageOf(error)),
              ),
            ],
          ),
          data: (i) => ListView(
            key: const Key('invite-page'),
            padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: CircleIconButton(icon: LucideIcons.arrowLeft, tooltip: 'Voltar', onPressed: () => context.go('/')),
              ),
              const SizedBox(height: 16),
              const LabelText('Convite de'),
              Text(i.trainerName.toUpperCase(), key: const Key('invite-trainer'), style: AppText.display(34)),
              if (i.headline != null) Text(i.headline!, style: AppText.body(size: 15, color: AppColors.textSecondary)),
              if (i.city != null || i.online)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    [
                      if (i.city != null) [i.city, i.state].whereType<String>().join('/'),
                      if (i.online) 'online',
                      if (i.inPerson) 'presencial',
                    ].join(' · '),
                    style: AppText.body(size: 13, color: AppColors.textMuted),
                  ),
                ),
              const SizedBox(height: 18),
              AppCard(
                radius: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.planName, style: AppText.body(size: 17, weight: FontWeight.w600)),
                    Text('${formatPrice(i.priceCents)} por mês', key: const Key('invite-price'), style: AppText.display(28, color: AppColors.volt)),
                    if ((i.planDescription ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(i.planDescription!.trim(), style: AppText.body(size: 14, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (hasTrainer)
                const InfoAlert(
                  key: Key('invite-has-trainer'),
                  kind: AlertKind.warn,
                  icon: LucideIcons.info,
                  text: 'Você já treina com um personal. Para assinar este plano, encerre o acompanhamento atual.',
                )
              else if (!i.available)
                const InfoAlert(
                  key: Key('invite-unavailable'),
                  kind: AlertKind.warn,
                  icon: LucideIcons.info,
                  text: 'Este personal ainda não está recebendo pagamentos. Tente de novo mais tarde.',
                )
              else ...[
                PillButton(
                  key: const Key('invite-subscribe'),
                  label: _busy ? 'Abrindo…' : 'Assinar e começar',
                  icon: LucideIcons.creditCard,
                  onPressed: _busy ? null : _subscribe,
                ),
                const SizedBox(height: 8),
                Text(
                  'O pagamento é feito no site seguro do Stripe. Depois de confirmado, você passa a treinar com este personal pelo app.',
                  style: AppText.body(size: 12.5, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Aluno sem personal digita o código que recebeu. Abre o convite.
Future<void> enterInviteCode(BuildContext context) async {
  final code = await showDialog<String>(context: context, builder: (context) => const _InviteCodeDialog());
  if (code == null || code.isEmpty || !context.mounted) return;
  context.push('/convite/${Uri.encodeComponent(code.toLowerCase())}');
}

class _InviteCodeDialog extends StatefulWidget {
  const _InviteCodeDialog();

  @override
  State<_InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<_InviteCodeDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Código de convite'),
      content: TextField(
        key: const Key('invite-code-field'),
        controller: _code,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Ex.: k7m2p9x4ab'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Voltar')),
        FilledButton(
          key: const Key('invite-code-open'),
          onPressed: () => Navigator.of(context).pop(_code.text.trim()),
          child: const Text('Abrir'),
        ),
      ],
    );
  }
}
