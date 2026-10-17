import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/pill_button.dart';

/// Moldura das telas de conta (cadastro, código, senha): voltar, título e conteúdo rolável.
class AccountScaffold extends StatelessWidget {
  const AccountScaffold({super.key, required this.title, this.subtitle, required this.children});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: CircleIconButton(
                    key: const Key('account-back'),
                    icon: LucideIcons.arrowLeft,
                    tooltip: 'Voltar',
                    onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(title.toUpperCase(), style: AppText.display(34)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AppText.body(size: 14.5, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mensagem de erro do formulário (texto sempre presente; a cor só reforça).
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(message, key: const Key('account-error'), style: AppText.body(size: 14, color: AppColors.danger)),
      );
}

String? validateEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Informe o e-mail';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) return 'E-mail inválido';
  return null;
}

String? validateNewPassword(String? value) {
  final text = value ?? '';
  if (text.length < 8) return 'A senha precisa ter pelo menos 8 caracteres';
  if (text.length > 72) return 'Senha longa demais';
  return null;
}
