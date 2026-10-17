import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/widgets/pill_button.dart';
import '../application/account_providers.dart';
import 'account_scaffold.dart';

/// "Esqueci minha senha": pede o código por e-mail e troca a senha com ele.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, this.args = const AccountFlowArgs()});

  final AccountFlowArgs args;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.args.email ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    final invalid = validateEmail(_email.text);
    if (invalid != null) return setState(() => _error = invalid);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).forgotPassword(_email.text);
      if (mounted) setState(() => _codeSent = true);
    } catch (error) {
      if (mounted) setState(() => _error = messageOf(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(accountRepositoryProvider).resetPassword(_email.text, _code.text, _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha alterada. Entre com a nova senha.')));
      context.go('/login');
    } catch (error) {
      if (mounted) setState(() => _error = messageOf(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_codeSent) {
      return AccountScaffold(
        title: 'Esqueci a senha',
        subtitle: 'Informe o e-mail da conta. Vamos enviar um código para você criar uma senha nova.',
        children: [
          TextField(
            key: const Key('reset-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _sendCode(),
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          if (_error != null) FormError(_error!),
          const SizedBox(height: 18),
          PillButton(key: const Key('reset-send'), label: _saving ? 'Enviando...' : 'Enviar código', onPressed: _saving ? null : _sendCode),
        ],
      );
    }
    return AccountScaffold(
      title: 'Nova senha',
      subtitle: 'Se houver uma conta com ${_email.text.trim()}, enviamos um código de 6 números. Ele vale por 30 minutos.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('reset-code'),
                controller: _code,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofillHints: const [AutofillHints.oneTimeCode],
                style: AppText.display(36).copyWith(letterSpacing: 10),
                decoration: const InputDecoration(hintText: '000000', counterText: ''),
                validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '') ? null : 'O código tem 6 números',
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('reset-password'),
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Nova senha', helperText: 'Pelo menos 8 caracteres'),
                validator: validateNewPassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('reset-confirm'),
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Repita a nova senha'),
                validator: (v) => v != _password.text ? 'As senhas não são iguais' : null,
              ),
            ],
          ),
        ),
        if (_error != null) FormError(_error!),
        const SizedBox(height: 18),
        PillButton(key: const Key('reset-submit'), label: _saving ? 'Salvando...' : 'Trocar senha', onPressed: _saving ? null : _reset),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('reset-again'),
          onPressed: _saving ? null : () => setState(() => _codeSent = false),
          child: const Text('Não recebeu? Enviar de novo'),
        ),
      ],
    );
  }
}
