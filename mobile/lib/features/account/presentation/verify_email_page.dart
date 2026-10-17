import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/widgets/pill_button.dart';
import '../../auth/application/auth_controller.dart';
import '../application/account_providers.dart';
import 'account_scaffold.dart';

const _resendSeconds = 60;

/// Código de 6 números enviado por e-mail para confirmar a conta.
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key, this.args = const AccountFlowArgs()});

  final AccountFlowArgs args;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  late final _email = TextEditingController(text: widget.args.email ?? '');
  final _code = TextEditingController();
  bool _saving = false;
  String? _error;
  String? _info;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.args.resend && (widget.args.email ?? '').isNotEmpty) {
      // veio do login: o código antigo pode ter expirado
      WidgetsBinding.instance.addPostFrameCallback((_) => _resend());
    } else if ((widget.args.email ?? '').isNotEmpty) {
      _startCooldown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    if (validateEmail(_email.text) != null) {
      setState(() => _error = 'Informe o e-mail da conta.');
      return;
    }
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await ref.read(accountRepositoryProvider).resendVerification(_email.text);
      if (!mounted) return;
      setState(() => _info = 'Enviamos um código novo para ${_email.text.trim()}.');
      _startCooldown();
    } catch (error) {
      if (mounted) setState(() => _error = messageOf(error));
    }
  }

  Future<void> _verify() async {
    final email = _email.text.trim();
    if (validateEmail(email) != null) return setState(() => _error = 'Informe o e-mail da conta.');
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) return setState(() => _error = 'O código tem 6 números.');
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref.read(accountRepositoryProvider).verifyEmail(email, _code.text);
      if (!mounted) return;
      if (result.guardianPending) {
        context.pushReplacement('/guardian-pending', extra: AccountFlowArgs(email: email, guardianEmail: result.guardianEmail));
        return;
      }
      final password = widget.args.password;
      if (password != null) {
        // acabou de se cadastrar: entra direto
        await ref.read(authControllerProvider.notifier).login(email, password);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-mail confirmado. Entre com sua senha.')));
      context.go('/login');
    } catch (error) {
      if (mounted) setState(() => _error = messageOf(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final knownEmail = (widget.args.email ?? '').isNotEmpty;
    return AccountScaffold(
      title: 'Confirme seu e-mail',
      subtitle: knownEmail
          ? 'Enviamos um código de 6 números para ${widget.args.email}. Confira também a caixa de spam.'
          : 'Informe o e-mail da conta e o código de 6 números que enviamos.',
      children: [
        if (!knownEmail) ...[
          TextField(
            key: const Key('verify-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          key: const Key('verify-code'),
          controller: _code,
          autofocus: knownEmail,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppText.display(36).copyWith(letterSpacing: 10),
          autofillHints: const [AutofillHints.oneTimeCode],
          onSubmitted: (_) => _verify(),
          decoration: const InputDecoration(hintText: '000000', counterText: ''),
        ),
        if (_error != null) FormError(_error!),
        if (_info != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(_info!, key: const Key('verify-info'), style: AppText.body(size: 14))),
        const SizedBox(height: 18),
        PillButton(key: const Key('verify-submit'), label: _saving ? 'Confirmando...' : 'Confirmar', onPressed: _saving ? null : _verify),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('verify-resend'),
          onPressed: _cooldown > 0 ? null : _resend,
          child: Text(_cooldown > 0 ? 'Reenviar código em ${_cooldown}s' : 'Reenviar código'),
        ),
      ],
    );
  }
}
