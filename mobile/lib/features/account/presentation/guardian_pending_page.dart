import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/widgets/pill_button.dart';
import '../application/account_providers.dart';
import 'account_scaffold.dart';

/// Conta de quem tem 12 a 17 anos: espera o responsável autorizar pelo link do e-mail.
class GuardianPendingPage extends ConsumerStatefulWidget {
  const GuardianPendingPage({super.key, this.args = const AccountFlowArgs()});

  final AccountFlowArgs args;

  @override
  ConsumerState<GuardianPendingPage> createState() => _GuardianPendingPageState();
}

class _GuardianPendingPageState extends ConsumerState<GuardianPendingPage> {
  bool _sending = false;

  Future<void> _resend() async {
    final email = widget.args.email;
    if (email == null) return;
    setState(() => _sending = true);
    final ok = await runAction(context, () => ref.read(accountRepositoryProvider).resendGuardian(email));
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido reenviado ao responsável.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final to = widget.args.guardianEmail;
    return AccountScaffold(
      title: 'Falta o responsável',
      subtitle: to == null
          ? 'Enviamos um pedido de autorização para o e-mail do seu responsável.'
          : 'Enviamos um pedido de autorização para $to.',
      children: [
        const Icon(LucideIcons.mailCheck, size: 48, color: AppColors.volt),
        const SizedBox(height: 12),
        Text(
          'Quando ele abrir o link e autorizar, sua conta é liberada e você já pode entrar. '
          'O link vale por 7 dias.',
          key: const Key('guardian-pending'),
          style: AppText.body(size: 14.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 22),
        PillButton(key: const Key('guardian-login'), label: 'Ele já autorizou: entrar', onPressed: () => context.go('/login')),
        const SizedBox(height: 8),
        if (widget.args.email != null)
          TextButton(
            key: const Key('guardian-resend'),
            onPressed: _sending ? null : _resend,
            child: const Text('Reenviar o pedido'),
          ),
      ],
    );
  }
}
