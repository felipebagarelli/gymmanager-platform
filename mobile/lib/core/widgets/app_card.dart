import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Card padrão: fundo `surface`, borda sutil e cantos de 20.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.borderColor = AppColors.borderSubtle,
    this.radius = 20,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Material(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: shape, side: BorderSide(color: borderColor)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Rótulo pequeno em caixa alta (ex.: "EXERCÍCIOS").
class LabelText extends StatelessWidget {
  const LabelText(this.text, {super.key, this.color = AppColors.textMuted, this.size = 11});

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: AppText.label(color: color, size: size));
}

/// Cabeçalho de seção: título condensado + ação opcional à direita.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title.toUpperCase(), style: AppText.display(18, weight: FontWeight.w600).copyWith(letterSpacing: 1.4)),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

/// Chip de texto com fundo translúcido; com [color] vira uma "tag" colorida.
class TagChip extends StatelessWidget {
  const TagChip(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c == null ? AppColors.overlay : c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: AppText.body(size: 12, weight: FontWeight.w600, color: c ?? AppColors.textSecondary)),
    );
  }
}

enum AlertKind { warn, good }

/// Faixa de aviso: laranja (atenção) ou verde (confirmação). Sempre com ícone e texto.
class InfoAlert extends StatelessWidget {
  const InfoAlert({super.key, required this.kind, required this.icon, required this.text});

  final AlertKind kind;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = kind == AlertKind.warn ? AppColors.ember : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.body(size: 14, weight: FontWeight.w500))),
        ],
      ),
    );
  }
}

/// Avatar circular com as iniciais do nome, em gradiente volt.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 42});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.avatarGradient),
      child: Text(
        trimmed.isEmpty ? '?' : trimmed[0].toUpperCase(),
        style: AppText.display(size * 0.45, color: AppColors.onVolt),
      ),
    );
  }
}
