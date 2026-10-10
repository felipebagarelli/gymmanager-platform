import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

enum PillStyle { volt, dark, ghost }

/// Botão principal do app: sempre em formato pill (totalmente arredondado).
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = PillStyle.volt,
    this.icon,
    this.height = 54,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillStyle style;
  final IconData? icon;
  final double height;

  /// `false` para o botão ocupar só a largura do conteúdo (ex.: "Registrar").
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (Color fg, BoxDecoration deco) = switch (style) {
      PillStyle.volt => (
          AppColors.onVolt,
          BoxDecoration(gradient: AppColors.ctaGradient, borderRadius: BorderRadius.circular(height / 2)),
        ),
      PillStyle.dark => (
          AppColors.volt,
          BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(height / 2)),
        ),
      PillStyle.ghost => (
          AppColors.textPrimary,
          BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: AppColors.borderStrong, width: 1.5),
          ),
        ),
    };

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 10)],
        Flexible(
          child: Text(
            label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: AppText.body(size: height < 48 ? 13 : 15, weight: FontWeight.w700, color: fg).copyWith(letterSpacing: 1),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: deco,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(height / 2),
              child: Container(
                constraints: BoxConstraints(minHeight: height, minWidth: 44),
                padding: EdgeInsets.symmetric(horizontal: expand ? 16 : 22),
                alignment: Alignment.center,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão redondo de ícone (voltar, mais opções...). Alvo de toque de 44 px ou mais.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.size = 42});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: SizedBox(
          width: size < 44 ? 44 : size,
          height: size < 44 ? 44 : size,
          child: Center(
            child: Material(
              color: AppColors.surface,
              shape: const CircleBorder(side: BorderSide(color: AppColors.borderSubtle)),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox(width: size, height: size, child: Icon(icon, size: 20, color: AppColors.textPrimary)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
