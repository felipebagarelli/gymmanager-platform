import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/widgets/pill_button.dart';
import '../../billing/domain/billing.dart';
import '../application/invite_providers.dart';
import '../data/invite_repository.dart';

/// Personal: link de convite de um plano para mandar a quem vai virar aluno.
Future<void> showShareInviteSheet(BuildContext context, {required Plan plan}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.elevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => _ShareInviteSheet(plan: plan),
  );
}

/// Texto que vai junto do link.
String inviteMessage(Plan plan, String url) =>
    'Vamos treinar juntos no GymManager! Assine o plano "${plan.name}" (${formatPrice(plan.priceCents)}/mês) por este link: $url';

class _ShareInviteSheet extends ConsumerStatefulWidget {
  const _ShareInviteSheet({required this.plan});

  final Plan plan;

  @override
  ConsumerState<_ShareInviteSheet> createState() => _ShareInviteSheetState();
}

class _ShareInviteSheetState extends ConsumerState<_ShareInviteSheet> {
  InviteLink? _link;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(ref.read(inviteRepositoryProvider).link(widget.plan.id));
  }

  Future<void> _load(Future<InviteLink> request) async {
    setState(() => _error = null);
    try {
      final link = await request;
      if (mounted) setState(() => _link = link);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gerar link novo?'),
        content: const Text('O link atual para de funcionar. Quem já assinou continua normalmente.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Voltar')),
          FilledButton(key: const Key('confirm-reset-invite'), onPressed: () => Navigator.of(context).pop(true), child: const Text('Gerar')),
        ],
      ),
    );
    if (ok == true) await _load(ref.read(inviteRepositoryProvider).reset(widget.plan.id));
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    return Padding(
      key: const Key('share-invite-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('CONVIDAR PARA O PLANO', style: AppText.display(26)),
          Text(
            'Quem recebe o link cria a conta no app e assina "${widget.plan.name}". '
            'Depois do pagamento, vira seu aluno automaticamente.',
            style: AppText.body(size: 13.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(messageOf(_error!), key: const Key('invite-link-error'), style: AppText.body(color: AppColors.danger))
          else if (link == null)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else ...[
            SelectableText(link.url, key: const Key('invite-url'), style: AppText.body(size: 14, color: AppColors.volt)),
            const SizedBox(height: 4),
            Text('Código: ${link.code}', key: const Key('invite-code'), style: AppText.body(size: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            PillButton(
              key: const Key('share-invite'),
              label: 'Compartilhar link',
              icon: LucideIcons.share2,
              onPressed: () => ref.read(shareTextProvider)(inviteMessage(widget.plan, link.url)),
            ),
            const SizedBox(height: 8),
            PillButton(
              key: const Key('copy-invite'),
              label: 'Copiar link',
              icon: LucideIcons.copy,
              style: PillStyle.ghost,
              height: 46,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link.url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado')));
                }
              },
            ),
            TextButton(key: const Key('reset-invite'), onPressed: _reset, child: const Text('Gerar link novo')),
          ],
        ],
      ),
    );
  }
}
