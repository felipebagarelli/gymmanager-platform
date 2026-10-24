import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/async_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../billing/application/billing_providers.dart';
import '../application/account_providers.dart';
import '../data/account_repository.dart';

/// Um campo do formulário de "corrigir meus dados".
class EditField {
  const EditField(this.key, this.label, this.initial, {this.keyboard, this.required = false, this.helper});

  final String key;
  final String label;
  final String initial;
  final TextInputType? keyboard;
  final bool required;
  final String? helper;
}

/// Folha com os campos para o usuário corrigir os próprios dados. Retorna os valores (já sem espaços
/// nas pontas) ou null se a pessoa fechou. [validate] devolve a mensagem de erro de cada campo.
Future<Map<String, String>?> showEditFieldsSheet(BuildContext context,
    {required String title, required List<EditField> fields, Map<String, String?> Function(Map<String, String>)? validate}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.elevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => _EditFieldsSheet(title: title, fields: fields, validate: validate),
  );
}

class _EditFieldsSheet extends StatefulWidget {
  const _EditFieldsSheet({required this.title, required this.fields, this.validate});

  final String title;
  final List<EditField> fields;
  final Map<String, String?> Function(Map<String, String>)? validate;

  @override
  State<_EditFieldsSheet> createState() => _EditFieldsSheetState();
}

class _EditFieldsSheetState extends State<_EditFieldsSheet> {
  late final Map<String, TextEditingController> _controllers = {
    for (final f in widget.fields) f.key: TextEditingController(text: f.initial),
  };
  Map<String, String?> _errors = const {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final values = {for (final e in _controllers.entries) e.key: e.value.text.trim()};
    final errors = <String, String?>{
      for (final f in widget.fields)
        if (f.required && values[f.key]!.isEmpty) f.key: 'Preencha este campo.',
      ...?widget.validate?.call(values),
    }..removeWhere((_, v) => v == null);
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: const Key('edit-data-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title.toUpperCase(), style: AppText.display(30)),
            const SizedBox(height: 14),
            for (final f in widget.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  key: Key('edit-${f.key}'),
                  controller: _controllers[f.key],
                  keyboardType: f.keyboard,
                  style: AppText.body(size: 15.5),
                  decoration: InputDecoration(labelText: f.label, errorText: _errors[f.key], helperText: f.helper),
                ),
              ),
            const SizedBox(height: 4),
            FilledButton(key: const Key('save-data'), onPressed: _save, child: const Text('Salvar')),
          ],
        ),
      ),
    );
  }
}

/// "Privacidade e termos": abre os documentos publicados (ou avisa que ainda estão em preparação).
Future<void> showLegalDocuments(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final opener = ref.read(urlOpenerProvider);
  LegalInfo? legal;
  try {
    legal = await ref.read(accountRepositoryProvider).legal();
  } catch (_) {
    // sem conexão: os itens avisam que o documento não abriu
  }
  if (!context.mounted) return;

  Future<void> open(String? url) async {
    Navigator.of(context).pop();
    if (url == null || !await opener(url)) {
      messenger.showSnackBar(const SnackBar(content: Text('Documento em preparação. Em breve ele fica disponível aqui.')));
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.elevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => Padding(
      key: const Key('legal-sheet'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('open-terms'),
            leading: const Icon(LucideIcons.fileText),
            title: const Text('Termos de uso'),
            onTap: () => open(legal?.termsUrl),
          ),
          ListTile(
            key: const Key('open-privacy'),
            leading: const Icon(LucideIcons.shieldCheck),
            title: const Text('Política de privacidade'),
            onTap: () => open(legal?.privacyUrl),
          ),
        ],
      ),
    ),
  );
}

/// Exclusão da conta: explica o que acontece, pede a senha e, se der certo, sai do app.
Future<void> deleteMyAccount(BuildContext context, WidgetRef ref, {required bool trainer}) async {
  final password = await showDialog<String>(
    context: context,
    builder: (context) => _DeleteAccountDialog(trainer: trainer),
  );
  if (password == null || !context.mounted) return;
  final ok = await runAction(context, () => ref.read(accountRepositoryProvider).deleteMyAccount(password));
  if (!ok || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sua conta foi excluída.')));
  await ref.read(authControllerProvider.notifier).logout();
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.trainer});

  final bool trainer;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Excluir conta?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.trainer
                  ? 'Seu perfil sai do hub, seus planos são desativados e seus dados de cadastro são apagados. '
                      'Antes, desative todos os seus alunos. Não dá para desfazer.'
                  : 'As cobranças são canceladas e seus dados de cadastro, de saúde e as conversas são apagados. '
                      'O histórico de treinos fica sem identificação. Não dá para desfazer.',
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('delete-account-password'),
              controller: _password,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Sua senha'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Voltar')),
        FilledButton(
          key: const Key('confirm-delete-account'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: _password.text.isEmpty ? null : () => Navigator.of(context).pop(_password.text),
          child: const Text('Excluir'),
        ),
      ],
    );
  }
}
