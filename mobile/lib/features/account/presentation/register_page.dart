import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/async_widgets.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../../billing/application/billing_providers.dart';
import '../application/account_providers.dart';
import '../data/account_repository.dart';
import 'account_scaffold.dart';

/// Cadastro aberto do aluno: dados, senha, nascimento, responsável (12 a 17 anos) e os aceites.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _birth = TextEditingController();
  final _guardianName = TextEditingController();
  final _guardianEmail = TextEditingController();
  bool _acceptTerms = false;
  bool _acceptHealth = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm, _birth, _guardianName, _guardianEmail]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _age(LegalInfo legal) {
    final birth = parseBirthDate(_birth.text);
    return birth == null ? null : ageOn(birth, ref.read(clockProvider)());
  }

  bool _isMinor(LegalInfo legal) {
    final age = _age(legal);
    return age != null && age >= legal.minimumAge && age < legal.adultAge;
  }

  Future<void> _openDocument(String? url) async {
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento em preparação.')));
      return;
    }
    await ref.read(urlOpenerProvider)(url);
  }

  Future<void> _submit(LegalInfo legal) async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    if (!_acceptTerms || !_acceptHealth) {
      setState(() => _error = 'Para criar a conta, marque as duas autorizações abaixo.');
      return;
    }
    final minor = _isMinor(legal);
    final draft = SignupDraft(
      name: _name.text,
      email: _email.text,
      password: _password.text,
      birthDate: parseBirthDate(_birth.text)!,
      termsVersion: legal.termsVersion,
      guardianName: minor ? _guardianName.text : null,
      guardianEmail: minor ? _guardianEmail.text : null,
    );
    setState(() => _saving = true);
    try {
      await ref.read(accountRepositoryProvider).register(draft);
      if (!mounted) return;
      context.pushReplacement('/verify-email', extra: AccountFlowArgs(email: draft.email.trim(), password: draft.password));
    } catch (error) {
      if (mounted) setState(() => _error = messageOf(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final legal = ref.watch(legalInfoProvider);
    return legal.when(
      loading: () => const AccountScaffold(title: 'Criar conta', children: [Center(child: CircularProgressIndicator())]),
      error: (error, _) => AccountScaffold(
        title: 'Criar conta',
        children: [ErrorRetry(error: error, onRetry: () => ref.invalidate(legalInfoProvider))],
      ),
      data: (info) => _buildForm(info),
    );
  }

  Widget _buildForm(LegalInfo legal) {
    final age = _age(legal);
    final minor = _isMinor(legal);
    return AccountScaffold(
      title: 'Criar conta',
      subtitle: 'Registre e acompanhe seus treinos. Leva um minuto.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('signup-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => (v ?? '').trim().length < 2 ? 'Informe seu nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('signup-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('signup-password'),
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Senha', helperText: 'Pelo menos 8 caracteres'),
                validator: validateNewPassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('signup-confirm'),
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Repita a senha'),
                validator: (v) => v != _password.text ? 'As senhas não são iguais' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('signup-birth'),
                controller: _birth,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(labelText: 'Data de nascimento', hintText: 'dd/mm/aaaa'),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final birth = parseBirthDate(v ?? '');
                  if (birth == null) return 'Informe a data no formato dd/mm/aaaa';
                  final years = ageOn(birth, ref.read(clockProvider)());
                  if (years < 0 || years > 120) return 'Data inválida';
                  if (years < legal.minimumAge) return 'É preciso ter pelo menos ${legal.minimumAge} anos';
                  return null;
                },
              ),
              if (minor) ...[
                const SizedBox(height: 16),
                AppCard(
                  key: const Key('guardian-section'),
                  radius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Autorização de um responsável', style: AppText.body(size: 15.5, weight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'Como você tem $age anos, a conta só é liberada depois que um responsável autorizar. '
                        'Vamos mandar um pedido para o e-mail dele.',
                        style: AppText.body(size: 13.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('guardian-name'),
                        controller: _guardianName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nome do responsável'),
                        validator: (v) => (v ?? '').trim().length < 2 ? 'Informe o nome do responsável' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('guardian-email'),
                        controller: _guardianEmail,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'E-mail do responsável'),
                        validator: (v) {
                          final invalid = validateEmail(v);
                          if (invalid != null) return invalid;
                          if (v!.trim().toLowerCase() == _email.text.trim().toLowerCase()) {
                            return 'Precisa ser diferente do seu e-mail';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Consent(
          key: const Key('accept-terms'),
          value: _acceptTerms,
          onChanged: (v) => setState(() => _acceptTerms = v),
          child: Wrap(
            children: [
              Text('Li e aceito os ', style: AppText.body(size: 14)),
              _Link('Termos de uso', onTap: () => _openDocument(legal.termsUrl)),
              Text(' e a ', style: AppText.body(size: 14)),
              _Link('Política de privacidade', onTap: () => _openDocument(legal.privacyUrl)),
              Text('.', style: AppText.body(size: 14)),
            ],
          ),
        ),
        _Consent(
          key: const Key('accept-health'),
          value: _acceptHealth,
          onChanged: (v) => setState(() => _acceptHealth = v),
          child: Text(
            'Autorizo o uso dos meus dados de treino e de saúde (como peso, altura e respostas sobre saúde) '
            'para montar e acompanhar meus treinos.',
            style: AppText.body(size: 14),
          ),
        ),
        if (_error != null) FormError(_error!),
        const SizedBox(height: 18),
        PillButton(
          key: const Key('signup-submit'),
          label: _saving ? 'Criando...' : 'Criar conta',
          onPressed: _saving ? null : () => _submit(legal),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => context.go('/login'), child: const Text('Já tenho conta')),
      ],
    );
  }
}

class _Consent extends StatelessWidget {
  const _Consent({super.key, required this.value, required this.onChanged, required this.child});

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.volt,
            checkColor: AppColors.onVolt,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(onTap: () => onChanged(!value), child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.text, {required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        link: true,
        child: GestureDetector(
          onTap: onTap,
          child: Text(text, style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.volt)),
        ),
      );
}
